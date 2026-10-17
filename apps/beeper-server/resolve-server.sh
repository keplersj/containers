#!/usr/bin/env bash
# resolve-server.sh [CHANNEL] > server.lock.env
# Reads Beeper's update feed the same way `beeper install server` does (feedURLFor() in
# beeper/cli packages/cli/src/lib/installations.ts), downloads each arch's artifact once to hash
# it, and prints a complete server.lock.env. Run by the beeper-server-feed workflow; needs curl,
# jq and sha256sum, and network access to api.beeper.com.
set -euo pipefail
channel=${1:-stable}
feed_base=${BEEPER_FEED_BASE:-https://api.beeper.com}
bundle=com.automattic.beeper.server
[[ "$channel" == nightly ]] && bundle="${bundle}.nightly"

version="" ; declare -A url sha
for arch in amd64 arm64; do
  feed_arch=$([[ $arch == amd64 ]] && echo x64 || echo arm64)
  feed=$(curl -fsSL --retry 3 "${feed_base}/desktop/update-feed.json?bundleID=${bundle}&platform=linux&channel=${channel}&arch=${feed_arch}")
  v=$(jq -r '.version // .name // empty' <<<"$feed")
  u=$(jq -r '.url // .downloadURL // .downloadUrl // empty' <<<"$feed")
  [[ -n "$v" && -n "$u" ]] || { echo "feed for ${arch} has no version/url: ${feed}" >&2; exit 1; }
  # Same guard as the CLI: refuse anything that isn't a Server artifact for this channel.
  file=$(basename "${u%%\?*}" | tr '[:upper:]' '[:lower:]')
  [[ "$file" == beeper-server-* ]] || { echo "feed for ${arch} returned a non-Server artifact: ${file}" >&2; exit 1; }
  if [[ "$channel" == stable && "$file" == *nightly* ]]; then echo "stable feed returned nightly artifact" >&2; exit 1; fi
  if [[ -n "$version" && "$v" != "$version" ]]; then echo "arch versions differ: ${version} vs ${v}" >&2; exit 1; fi
  version=$v
  url[$arch]=$u
  sha[$arch]=$(curl -fsSL --retry 3 "$u" | sha256sum | cut -d' ' -f1)
done

cat <<LOCK
# Beeper Server artifacts baked into the image. Written ONLY by
# .github/workflows/beeper-server-feed.yaml (resolve-server.sh) -- do not edit by hand.
# The feed publishes no checksum; these sha256s are what the workflow downloaded on
# $(date -u +%Y-%m-%d). Review the PR it opens: a change here is a server upgrade.
BEEPER_SERVER_CHANNEL=${channel}
BEEPER_SERVER_VERSION=${version}
BEEPER_SERVER_URL_amd64=${url[amd64]}
BEEPER_SERVER_SHA256_amd64=${sha[amd64]}
BEEPER_SERVER_URL_arm64=${url[arm64]}
BEEPER_SERVER_SHA256_arm64=${sha[arm64]}
LOCK
