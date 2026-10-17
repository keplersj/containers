#!/bin/sh
# Runs beeper-server in the foreground (PID 1 is tini). Same flags the CLI's own launcher passes
# (serverArgs() in beeper/cli packages/cli/src/lib/profiles.ts), except --host, which the CLI pins
# to 127.0.0.1 and we default to 0.0.0.0 so the pod's Service can reach it. Extra flags pass
# through: `beeper-server-entrypoint --some-flag`.
set -eu
umask 077
mkdir -p "${BEEPER_SERVER_DATA_DIR}" "${BEEPER_CLI_CONFIG_DIR}"
exec /usr/local/bin/beeper-server \
  --host="${BEEPER_SERVER_HOST}" \
  --port="${BEEPER_SERVER_PORT}" \
  --data-dir="${BEEPER_SERVER_DATA_DIR}" \
  --server-env="${BEEPER_SERVER_ENV}" \
  "$@"
