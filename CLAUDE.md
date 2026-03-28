# CLAUDE.md

## Project Overview

Multi-platform Docker image for [DLib](https://github.com/davisking/dlib) (C++ toolkit for machine learning). Builds for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` using Ubuntu Noble as the base image with DLib installed from the system package (`libdlib-dev`).

## Build & Test

```bash
make help              # list all targets
make deps              # verify docker is installed
make build             # build Docker image (all platforms)
make test              # run container smoke test
make lint              # lint Dockerfile with hadolint
make ci                # full pipeline: deps, lint, build, test
make bootstrap         # create multi-platform buildx builder (required once)
```

## Key Variables (Makefile)

| Variable | Default | Purpose |
|----------|---------|---------|
| `DLIB_VERSION` | `20.0` | DLib version |
| `BUILDER_IMAGE` | `ubuntu:noble-20260113` | Base Docker image |
| `IMAGE_NAME` | `anriykalashnykov/dblib-docker` | Docker image name |

## CI/CD

- **`.github/workflows/ci.yml`** -- builds and optionally pushes to `ghcr.io` on tags matching `v*`
- **`.github/workflows/cleanup-runs.yml`** -- housekeeping for workflow runs
- Images are pushed only on tag events (`github.ref_type == 'tag'`)
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
