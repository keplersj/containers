#!/usr/bin/env bash
# fetch-server.sh LOCKFILE ARCH OUT
# Downloads the beeper-server artifact pinned in LOCKFILE for ARCH (amd64|arm64), verifies its
# sha256, and installs the executable at OUT. Artifact handling mirrors the CLI's own installer
# (packages/cli/src/lib/installations.ts in beeper/cli): .tar.gz/.tgz, .zip, or a bare binary,
# with the executable named beeper-server somewhere inside.
set -euo pipefail
lock=$1 arch=$2 out=$3

# shellcheck disable=SC1090
source "$lock"
url_var="BEEPER_SERVER_URL_${arch}" sha_var="BEEPER_SERVER_SHA256_${arch}"
url=${!url_var:-} sha=${!sha_var:-}
if [[ -z "$url" || "$url" == UNRESOLVED || -z "$sha" || "$sha" == UNRESOLVED ]]; then
  echo "server.lock.env has no resolved artifact for ${arch}." >&2
  echo "Run the beeper-server-feed workflow (Actions -> beeper-server-feed -> Run workflow) and merge its PR." >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
name=$(basename "${url%%\?*}")
curl -fsSL --retry 3 -o "$work/$name" "$url"
echo "${sha}  $work/$name" | sha256sum -c -

mkdir "$work/x"
case "$name" in
  *.tar.gz|*.tgz) tar -xzf "$work/$name" -C "$work/x" --no-same-owner ;;
  *.zip) unzip -q "$work/$name" -d "$work/x" ;;
  *) cp "$work/$name" "$work/x/beeper-server" ;;
esac
bin=$(find "$work/x" -type f -name beeper-server | head -n1)
[[ -n "$bin" ]] || { echo "artifact ${name} contains no beeper-server executable" >&2; exit 1; }
install -m 0755 "$bin" "$out"
echo "installed beeper-server ${BEEPER_SERVER_VERSION} (${arch}) from ${name}"
