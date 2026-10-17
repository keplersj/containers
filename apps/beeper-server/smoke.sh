#!/usr/bin/env bash
# smoke.sh IMAGE -- start the image with no account and check what an unauthenticated client sees.
# Runs in CI before any push. Needs no Beeper login, so it can't test messaging; it does answer:
#   - does beeper-server start as uid 10001 on a read-only root fs with an empty /data?
#   - does it answer /v1/info for a NON-loopback client? (requests arrive via Docker's port
#     mapping, i.e. from the bridge gateway, as they would from a Kubernetes Service)
#   - what does it report for mcp_enabled / remote_access / hostname, and does /v0/mcp exist?
set -euo pipefail
image=$1 name=beeper-smoke port=23373
cleanup() { docker logs "$name" >smoke.log 2>&1 || true; docker rm -f "$name" >/dev/null 2>&1 || true; docker volume rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$name" --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  -v "$name":/data -p "127.0.0.1:${port}:${port}" "$image" >/dev/null

info=""
for _ in $(seq 1 60); do
  if ! docker ps -q --filter "name=^${name}$" | grep -q .; then
    echo "::error::beeper-server exited during startup"; docker logs "$name" 2>&1 | tail -50; exit 1
  fi
  code=$(curl -s -o info.json -w '%{http_code}' "http://127.0.0.1:${port}/v1/info" || true)
  if [[ "$code" == 200 ]]; then info=$(cat info.json); break; fi
  sleep 2
done
if [[ -z "$info" ]]; then
  echo "::error::/v1/info never returned 200 to a non-loopback client (last status: ${code:-none})"
  docker logs "$name" 2>&1 | tail -50
  docker exec "$name" bash -c 'exec 3<>/dev/tcp/127.0.0.1/23373' 2>/dev/null && echo "(port IS open on loopback inside the container)"
  exit 1
fi

echo "== /v1/info (unauthenticated, non-loopback)"
jq '{app, platform, server, endpoints: (.endpoints | {mcp, spec, ws_events})}' info.json
# endpoints.mcp may be a full URL or a path; keep only the path.
mcp_path=$(jq -r '.endpoints.mcp // "/v0/mcp"' info.json | sed -E 's#^[a-z]+://[^/]+##')
[[ "$mcp_path" == /* ]] || mcp_path="/v0/mcp"
init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}'
for path in $(printf "%s\n" "$mcp_path" /v0/mcp | sort -u); do
  mcp_code=$(curl -s -o mcp.out -w '%{http_code}' -X POST "http://127.0.0.1:${port}${path}" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d "$init" || true)
  echo "== POST ${path} without a token -> HTTP ${mcp_code}"; head -c 300 mcp.out; echo
done
{
  echo "### beeper-server smoke ($(jq -r '.app.version' info.json))"
  echo '```json'; jq '{server, endpoints: {mcp: .endpoints.mcp}}' info.json; echo '```'
  echo "POST ${mcp_path} without a token: HTTP ${mcp_code} (401/403 = endpoint exists and wants auth; 404 = no MCP endpoint)"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
echo "smoke OK"
