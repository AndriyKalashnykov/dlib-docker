# CLAUDE.md

## Project Overview

Multi-platform Docker image for [DLib](https://github.com/davisking/dlib) (C++ toolkit for machine learning). Builds for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` using Ubuntu Noble as the base image with DLib installed from the Ubuntu `libdlib-dev` apt package (may lag upstream davisking/dlib releases).

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
| `DLIB_VERSION` | `20.0` | Upstream DLib version the project targets (documentation only; install path is `libdlib-dev` apt package) |
| `ACT_VERSION` | `0.2.87` | Local CI runner version |
| `HADOLINT_VERSION` | `2.14.0` | Dockerfile linter version |
| `NVM_VERSION` | `0.40.4` | Node Version Manager version (Renovate tooling) |
| `NODE_VERSION` | `$(cat .nvmrc)` | Node.js version for Renovate (source of truth: `.nvmrc`) |
| `IMAGE_NAME` | `andriykalashnykov/dlib-docker` | Local Docker image name |
| `APP_NAME` | `dlib-docker` | Project name |

The `ubuntu:noble-20260217` base image is pinned by digest in the Dockerfile and tracked by Renovate's native `dockerfile` manager — no Makefile constant needed.

## CI/CD

- **`.github/workflows/ci.yml`** -- three jobs:
  - `static-check` -- composite quality gate, runs `make static-check` (currently hadolint). Runs on pushes to `main`, tag pushes `v*`, and all PRs.
  - `docker` -- builds and pushes multi-arch image to `ghcr.io` (runs only on tag pushes `v*`, after `static-check` passes)
  - `ci-pass` -- aggregating gate job with `if: always()` and `needs: [static-check, docker]`, for branch protection
- **`.github/workflows/cleanup-runs.yml`** -- weekly housekeeping: prunes old workflow runs (`cleanup-runs` job) and stale GitHub Actions caches from deleted branches (`cleanup-caches` job)
- Uses Docker Buildx with GHA caching; `provenance: false` + `sbom: false` keep the image index clean so GHCR's "OS / Arch" tab renders

## Upgrade Backlog

- [ ] dlib v20.0.1 released 2026-03-29 — Ubuntu `libdlib-dev` apt package may lag; check periodically
- [ ] Pre-push hardening missing (no Trivy image scan, no smoke test in CI, no cosign signing). Run `/harden-image-pipeline` for an interactive walkthrough.
- [ ] Investigate why Renovate hasn't been auto-bumping action SHAs — `docker/build-push-action` was stale (now fixed manually). Check Renovate Dashboard (`app.renovatebot.com/dashboard#github/AndriyKalashnykov/dlib-docker`) next time a PR is opened.
- [ ] Verify Renovate's `dockerfile` manager now tracks the inlined `FROM ubuntu:noble-20260217@sha256:...` line in the Dockerfile (the ARG indirection that was blocking it has been removed).

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
