# containers

Miscellaneous & Various OCI Containers.

Container images for upstream software that doesn't ship one (or ships one that doesn't fit),
published to `ghcr.io/keplersj/<app>`. Helm charts that use them live in
[keplersj/helm-charts](https://github.com/keplersj/helm-charts).

| Image | Upstream | Notes |
| --- | --- | --- |
| [`beeper-server`](apps/beeper-server) | [beeper/cli](https://github.com/beeper/cli) + Beeper's server update feed | Headless Beeper Server + `beeper` CLI, non-root, no systemd |

## Layout

Each `apps/<app>/` holds a `Dockerfile` (build context is that directory) and a `version.sh`
that prints the image tag.

## Releases

- **PR**: `build.yaml` builds every app for `linux/amd64` + `linux/arm64`, no push.
- **main**: same build, pushed to `ghcr.io/keplersj/<app>:<tag>` with provenance, SBOM and a
  GitHub attestation. **Tags are immutable**: an existing tag is skipped, so a release means
  changing what `version.sh` reads. Consumers pin `tag@digest`.
- Upstream versions are pinned with sha256s in each Dockerfile; Renovate bumps `# renovate:`
  annotated ARGs (the matching sha256 ARGs need updating in the same PR, so those never automerge).
  Sources Renovate can't read get their own scheduled workflow (e.g. `beeper-server-feed.yaml`).

## License

[MIT](LICENSE). Upstream software packaged here keeps its own license.
