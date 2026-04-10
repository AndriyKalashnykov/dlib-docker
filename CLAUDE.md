# CLAUDE.md

## Project Overview

Multi-platform Docker image for [DLib](https://github.com/davisking/dlib) (C++ toolkit for machine learning). Builds for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` using Ubuntu Noble as the base image with DLib compiled from source at the pinned upstream tag in `DLIB_VERSION` (Makefile). The project's git tag matches the dlib version it ships.

## Build & Test

```bash
make help              # list all targets
make deps              # verify docker is installed
make lint              # lint Dockerfile with hadolint (auto-installs via deps-hadolint)
make static-check      # composite quality gate (currently wraps lint)
make build             # build multi-platform image (auto-runs buildx-bootstrap)
make test              # run container smoke test
make ci                # full pipeline: deps, static-check, build, test
make ci-run            # run GitHub Actions workflow locally via act
make buildx-bootstrap  # create multi-platform buildx builder (standalone; build depends on it)
```

## Key Variables (Makefile)

| Variable | Default | Purpose |
|----------|---------|---------|
| `DLIB_VERSION` | `19.24.9` | Upstream davisking/dlib tag built from source in the Dockerfile (passed as `--build-arg`). Renovate-tracked via `datasource=github-tags depName=davisking/dlib`. Project convention: the git tag cut for a release matches this value. |
| `ACT_VERSION` | `0.2.87` | Local CI runner version |
| `HADOLINT_VERSION` | `2.14.0` | Dockerfile linter version |
| `NVM_VERSION` | `0.40.4` | Node Version Manager version (Renovate tooling) |
| `NODE_VERSION` | `$(cat .nvmrc)` | Node.js version for Renovate (source of truth: `.nvmrc`) |
| `IMAGE_NAME` | `andriykalashnykov/dlib-docker` | Local Docker image name |
| `APP_NAME` | `dlib-docker` | Project name |

The `ubuntu:noble-20260217` base image is pinned by digest in the Dockerfile and tracked by Renovate's native `dockerfile` manager — no Makefile constant needed.

## CI/CD

- **`.github/workflows/ci.yml`** -- three jobs:
  - `static-check` -- composite quality gate, runs `make static-check` (hadolint + trivy-fs). Runs on pushes to `main`, tag pushes `v*`, and all PRs.
  - `docker` -- on tag pushes `v*` only, runs the full hardening pipeline: build for scan → Trivy image scan (CRITICAL/HIGH blocking) → smoke test → multi-arch build and push → cosign keyless OIDC signing → create GitHub Release. Tag-gated at job level with 90-min budget for the QEMU-emulated dlib compile.
  - `ci-pass` -- aggregating gate job with `if: always()` and `needs: [static-check, docker]`, for branch protection. Catches both `failure` and `cancelled` results.
- **`.github/workflows/cleanup-runs.yml`** -- weekly housekeeping: prunes old workflow runs (`cleanup-runs` job) and stale GitHub Actions caches from deleted branches (`cleanup-caches` job)
- Uses Docker Buildx with GHA caching; `provenance: false` + `sbom: false` keep the image index clean so GHCR's "OS / Arch" tab renders; cosign keyless signing via Sigstore Fulcio provides supply-chain verification without in-manifest attestations

## Upgrade Backlog

_(No open items. Renovate `github-tags` tracking for `DLIB_VERSION` was verified via `npx renovate --platform=local --dry-run=lookup` — Renovate auto-selects `versioning: semver-coerced` for the davisking/dlib datasource, so the bare `20.0.1` in the Makefile matches upstream `v20.0.1` without any inline `versioning=` hint. All 5 regex-tracked tools — dlib, act, hadolint, trivy, nvm — extract correctly and report `updates: []` + `warnings: []`.)_

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
