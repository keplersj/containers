# beeper-server

Headless [Beeper Server](https://github.com/beeper/cli#2-local-beeper-server-self-hosted-managed-by-the-cli)
plus the `beeper` CLI, for running Beeper's Client API (and, if the server provides it, MCP) on a
cluster instead of a desktop.

## What's inside

| Path | What | Pinned by |
| --- | --- | --- |
| `/usr/local/bin/beeper-server` | Server runtime, from Beeper's update feed (`com.automattic.beeper.server`) | `server.lock.env` (URL + sha256 per arch) |
| `/usr/local/bin/beeper` | CLI, from `github.com/beeper/cli` releases | `BEEPER_CLI_VERSION` + sha256 ARGs (sha256s match the npm package's `binaries.json`) |
| `/opt/beeper-cli` | The CLI's ~400MB self-extracted payload, pre-warmed at build | (derived) |
| `/usr/local/bin/tini` | PID 1 / signal forwarding | `TINI_VERSION` + sha256 ARGs |

Base: `debian:trixie-slim` by digest. No apt at all (CA bundle is copied from the fetch stage).

## Runtime contract

- Runs `beeper-server --host=$BEEPER_SERVER_HOST --port=$BEEPER_SERVER_PORT --data-dir=$BEEPER_SERVER_DATA_DIR --server-env=$BEEPER_SERVER_ENV`
  in the foreground under tini, as uid/gid **10001**. These are the flags the CLI's own launcher
  uses, except `--host`, which the CLI hardcodes to `127.0.0.1` and this image defaults to `0.0.0.0`.
- **All state is under `/data`** (mount a volume): `/data/server` (login, device verification /
  encryption keys, bridge sessions) and `/data/cli` (CLI targets, including the stored access token).
- Works with a read-only root filesystem and all capabilities dropped.
- Don't run `beeper install server` / `beeper update --server` inside it: `BEEPER_SERVER_BIN`
  points the CLI at the baked binary. Upgrade by bumping the image.

## Upgrading the server

The feed has no checksums and isn't a Renovate datasource, so `.github/workflows/beeper-server-feed.yaml`
(weekly, or *Run workflow*) runs `resolve-server.sh`, hashes the artifacts and opens a PR rewriting
`server.lock.env`. Merging it builds `<server-version>-cli<cli-version>`.

**First build:** `server.lock.env` ships as `UNRESOLVED` (the feed host wasn't reachable from where
this was written). Run the feed workflow once and merge its PR; until then the build fails with a
message saying exactly that.

## Local build behind a TLS-intercepting proxy

```sh
docker build --secret id=extra_ca,src=/path/to/proxy-ca.crt -t beeper-server:dev apps/beeper-server
```
