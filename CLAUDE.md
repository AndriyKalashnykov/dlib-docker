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
| `DLIB_VERSION` | `20.0` | DLib version |
| `BUILDER_IMAGE` | `ubuntu:noble-20260217` | Base Docker image |
| `IMAGE_NAME` | `anriykalashnykov/dblib-docker` | Docker image name |
| `HADOLINT_VERSION` | `2.12.0` | Dockerfile linter version |
| `ACT_VERSION` | `0.2.86` | Local CI runner version |

## CI/CD

- **`.github/workflows/ci.yml`** -- two jobs:
  - `ci` -- lints Dockerfile via `make lint` (runs on all pushes and PRs)
  - `docker` -- builds and pushes multi-arch image to `ghcr.io` (runs only on tag pushes `v*`)
- **`.github/workflows/cleanup-runs.yml`** -- weekly housekeeping for old workflow runs
- Uses Docker Buildx with GHA caching

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
