[![CI](https://github.com/AndriyKalashnykov/dlib-docker/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/dlib-docker/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/dlib-docker.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/dlib-docker/)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/dlib-docker)

# dlib-docker

Multi-platform Docker image for [DLib](https://github.com/davisking/dlib) (C++ machine learning toolkit). Builds for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` using Ubuntu Noble as the base image with DLib 20.0 installed from the system package (`libdlib-dev`).

## Quick Start

```bash
make deps              # verify Docker is installed
make buildx-bootstrap  # create multi-platform buildx builder (first time only)
make build             # build Docker image for all platforms
make test              # run container smoke test
make run               # run the image interactively (amd64)
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Docker](https://www.docker.com/) | >= 27.5.1 | Container runtime and buildx |
| [hadolint](https://github.com/hadolint/hadolint) | 2.12.0 | Dockerfile linting (auto-installed by `make lint`) |
| [Git](https://git-scm.com/) | latest | Version control |
| [act](https://github.com/nektos/act) | 0.2.86 | Run GitHub Actions locally (optional) |

Install all required dependencies:

```bash
make deps
```

## Available Make Targets

Run `make help` to see all available targets.

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build the dlib Docker image (alias for image-build) |
| `make test` | Run container smoke test |
| `make lint` | Lint the Dockerfile with hadolint |
| `make run` | Run the dlib Docker image interactively (amd64) |
| `make clean` | Remove build artefacts and temporary files |

### Docker

| Target | Description |
|--------|-------------|
| `make buildx-bootstrap` | Bootstrap multi-platform Docker buildx builder |
| `make image-build` | Build dlib image for amd64, armv7, and arm64 |
| `make image-run` | Run dlib images interactively for all platforms |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full CI pipeline (deps, lint, build, test) |
| `make ci-run` | Run GitHub Actions workflow locally via [act](https://github.com/nektos/act) |

### Utilities

| Target | Description |
|--------|-------------|
| `make deps` | Verify required toolchain dependencies |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make release` | Create and push a new semver tag |
| `make tag-delete` | Delete a specific tag locally and from remote |
| `make renovate-bootstrap` | Install nvm and npm for Renovate |
| `make renovate-validate` | Validate Renovate configuration |

## CI/CD

GitHub Actions runs on every push to `main`, tags `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **ci** | push, PR, tags | Lint |
| **docker** | tag push (`v*`) | QEMU, Buildx, Build & Push to `ghcr.io` |

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.
