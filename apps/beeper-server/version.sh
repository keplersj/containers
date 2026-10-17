#!/usr/bin/env bash
# Prints this image's tag: <beeper-server version>-cli<beeper CLI version>, e.g. 4.1.2-cli0.6.2.
# Tags are immutable -- the build workflow skips a tag that already exists in GHCR.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source server.lock.env
cli=$(sed -n 's/^ARG BEEPER_CLI_VERSION=//p' Dockerfile | head -n1)
echo "${BEEPER_SERVER_VERSION}-cli${cli}"
