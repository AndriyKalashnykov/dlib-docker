# CLAUDE.md

## Project Overview

Multi-platform Docker image for [DLib](https://github.com/davisking/dlib) (C++ toolkit for machine learning). Builds for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` using Ubuntu Noble as the base image with DLib installed from the system package (`libdlib-dev`).

## Build & Test

```bash
make help              # list all targets
make deps              # verify docker is installed
make lint              # lint Dockerfile with hadolint (auto-installs via deps-hadolint)
make build             # build Docker image (all platforms)
make test              # run container smoke test
make ci                # full pipeline: deps, lint, build, test
make ci-run            # run GitHub Actions workflow locally via act
make buildx-bootstrap  # create multi-platform buildx builder (required once)
```

## Key Variables (Makefile)

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOCKER_VERSION` | `27.5.1` | Minimum Docker Engine version (informational) |
| `DLIB_VERSION` | `20.0` | DLib version |
| `BUILDER_IMAGE` | `ubuntu:noble-20260217` | Base Docker image |
| `ACT_VERSION` | `0.2.87` | Local CI runner version |
| `HADOLINT_VERSION` | `2.14.0` | Dockerfile linter version |
| `NVM_VERSION` | `0.40.4` | Node Version Manager version |
| `IMAGE_NAME` | `anriykalashnykov/dblib-docker` | Docker image name |

## CI/CD

- **`.github/workflows/ci.yml`** -- two jobs:
  - `ci` -- lints Dockerfile via `make lint` (runs on all pushes and PRs)
  - `docker` -- builds and pushes multi-arch image to `ghcr.io` (runs only on tag pushes `v*`)
- **`.github/workflows/cleanup-runs.yml`** -- weekly housekeeping for old workflow runs
- Uses Docker Buildx with GHA caching

## Upgrade Backlog

- [ ] dlib v20.0.1 released 2026-03-29 — Ubuntu `libdlib-dev` apt package may lag; check periodically
- [ ] `DOCKER_VERSION` in Makefile is informational only (no actual version check in `deps` target) — consider adding a real version check or removing the misleading `>=` from the error message

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
