# syntax=docker/dockerfile:1.10
#
# Headless Beeper Server (https://github.com/beeper/cli) for Kubernetes.
#
# Two upstream binaries, both pinned and checksum-verified:
#   - beeper        the CLI, from github.com/beeper/cli releases (sha256s published in the npm
#                   package's binaries.json -- see README.md)
#   - beeper-server the server runtime, from Beeper's update feed. The feed gives no checksum, so
#                   server.lock.env records the URL + sha256 we resolved per arch; it is only ever changed
#                   by the beeper-server-feed workflow, in a reviewable PR.
#
# No systemd, no `beeper targets enable`: the container runs beeper-server in the foreground under
# tini, as an unprivileged user. All state lives under /data (mount a volume there).

ARG DEBIAN_IMAGE=debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4
ARG FETCH_IMAGE=buildpack-deps:trixie-curl@sha256:3dd78c060b4d7c97b426d0160f7d8876c84fbf2fc36e651e9c75620ac9a7da24

# ---------------------------------------------------------------------------------------------
FROM ${FETCH_IMAGE} AS fetch
ARG TARGETARCH
# renovate: datasource=github-releases depName=beeper/cli
ARG BEEPER_CLI_VERSION=0.6.2
ARG BEEPER_CLI_SHA256_amd64=a881e1d2bc91e31218b251716644ec5f8d161d5ccb30e7eab66cf2ba6410511d
ARG BEEPER_CLI_SHA256_arm64=2bd37043a4ed863621edc59e28aaa652e8193e55abca0e9477f5aeae1c65d629
# renovate: datasource=github-releases depName=krallin/tini
ARG TINI_VERSION=0.19.0
ARG TINI_SHA256_amd64=c5b0666b4cb676901f90dfcb37106783c5fe2077b04590973b885950611b30ee
ARG TINI_SHA256_arm64=eae1d3aa50c48fb23b8cbdf4e369d0910dfc538566bfd09df89a774aa84a48b9

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
WORKDIR /out
COPY server.lock.env fetch-server.sh /src/

# Optional extra CA for builds behind a TLS-intercepting egress proxy (unused in CI):
#   docker build --secret id=extra_ca,src=/path/ca.crt ...
RUN --mount=type=secret,id=extra_ca,required=false \
    if [[ -s /run/secrets/extra_ca ]]; then export CURL_CA_BUNDLE=/run/secrets/extra_ca; fi; \
    case "${TARGETARCH}" in \
      amd64) cli_arch=x64;   cli_sha="${BEEPER_CLI_SHA256_amd64}"; tini_sha="${TINI_SHA256_amd64}" ;; \
      arm64) cli_arch=arm64; cli_sha="${BEEPER_CLI_SHA256_arm64}"; tini_sha="${TINI_SHA256_arm64}" ;; \
      *) echo "unsupported TARGETARCH ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o cli.tgz "https://github.com/beeper/cli/releases/download/v${BEEPER_CLI_VERSION}/beeper-cli-${BEEPER_CLI_VERSION}-linux-${cli_arch}.tar.gz"; \
    echo "${cli_sha}  cli.tgz" | sha256sum -c -; \
    mkdir cli && tar -xzf cli.tgz -C cli --no-same-owner --warning=no-unknown-keyword; \
    install -m 0755 cli/bin/beeper /out/beeper; \
    curl -fsSL -o /out/tini "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-${TARGETARCH}"; \
    echo "${tini_sha}  /out/tini" | sha256sum -c -; \
    chmod 0755 /out/tini; \
    /src/fetch-server.sh /src/server.lock.env "${TARGETARCH}" /out/beeper-server; \
    cp /etc/ssl/certs/ca-certificates.crt /out/ca-certificates.crt

# ---------------------------------------------------------------------------------------------
FROM ${DEBIAN_IMAGE}
ARG BEEPER_CLI_VERSION=0.6.2

# CA bundle copied from the fetch stage, so the runtime image needs no apt at all.
COPY --from=fetch /out/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=fetch /out/tini /usr/local/bin/tini
COPY --from=fetch /out/beeper /usr/local/bin/beeper
COPY --from=fetch /out/beeper-server /usr/local/bin/beeper-server
COPY entrypoint.sh /usr/local/bin/beeper-server-entrypoint

# The CLI binary unpacks a ~400MB payload into $BEEPER_CLI_BINARY_CACHE_DIR (default
# ~/.cache/beeper-cli) on first run. Do that once here, read-only in the image, instead of on the
# /data volume (where it would bloat every backup).
ENV BEEPER_CLI_BINARY_CACHE_DIR=/opt/beeper-cli
# Fixed numeric UID/GID so `runAsNonRoot` can verify it and fsGroup matches.
RUN groupadd --system --gid 10001 beeper \
 && useradd --system --uid 10001 --gid 10001 --home-dir /data --no-create-home --shell /usr/sbin/nologin beeper \
 && mkdir -p /data && chown 10001:10001 /data \
 && HOME=/tmp/warm beeper version >/dev/null 2>&1 \
 && rm -rf /tmp/warm \
 && chmod -R a+rX,go-w "${BEEPER_CLI_BINARY_CACHE_DIR}"

# HOME / BEEPER_CLI_CONFIG_DIR: CLI state (config.json, targets/*.json -- which holds the access
#   token -- and plugins). BEEPER_SERVER_DATA_DIR: server state (Beeper login, device verification /
#   encryption keys, bridge sessions). Both on the /data volume.
# BEEPER_SERVER_BIN makes the CLI use the baked-in binary rather than one `beeper install server`
#   would drop on the volume. Never run `beeper update --server` in the container; bump the image.
ENV HOME=/data \
    BEEPER_CLI_CONFIG_DIR=/data/cli \
    BEEPER_SERVER_DATA_DIR=/data/server \
    BEEPER_SERVER_BIN=/usr/local/bin/beeper-server \
    BEEPER_SERVER_HOST=0.0.0.0 \
    BEEPER_SERVER_PORT=23373 \
    BEEPER_SERVER_ENV=production \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

LABEL org.opencontainers.image.title="beeper-server" \
      org.opencontainers.image.description="Headless Beeper Server with the beeper CLI" \
      org.opencontainers.image.source="https://github.com/keplersj/containers" \
      org.opencontainers.image.licenses="MIT" \
      io.beeper.cli.version="${BEEPER_CLI_VERSION}"

USER 10001:10001
WORKDIR /data
VOLUME ["/data"]
EXPOSE 23373
ENTRYPOINT ["/usr/local/bin/tini", "--", "/usr/local/bin/beeper-server-entrypoint"]
