[![CI](https://github.com/AndriyKalashnykov/dlib-docker/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/dlib-docker/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/AndriyKalashnykov/dlib-docker)](https://github.com/AndriyKalashnykov/dlib-docker/releases/latest)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/dlib-docker.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/dlib-docker/)
[![License: CC0](https://img.shields.io/badge/License-CC0-brightgreen.svg)](https://creativecommons.org/publicdomain/zero/1.0/)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/dlib-docker)

# dlib-docker

Multi-platform Docker image for [DLib](https://github.com/davisking/dlib) (C++ machine learning toolkit). Builds for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` from Ubuntu Noble with DLib installed via the `libdlib-dev` apt package (version may lag upstream davisking/dlib releases).

| Component | Technology |
|-----------|-----------|
| Language | C++ (DLib toolkit) |
| Base Image | `ubuntu:noble-20260217` (digest-pinned) |
| DLib Source | `libdlib-dev` 20.0 (Ubuntu apt) |
| Platforms | `linux/amd64`, `linux/arm64`, `linux/arm/v7` |
| Container Runtime | Docker + Buildx (multi-platform builder) |
| Dockerfile Linter | [hadolint](https://github.com/hadolint/hadolint) 2.14.0 |
| CI/CD | GitHub Actions + GHCR multi-arch push |
| Dependency Updates | [Renovate](https://docs.renovatebot.com/) (branch automerge, squash) |

## Quick Start

```bash
make deps              # verify Docker is installed
make build             # build multi-platform image (creates buildx builder on first run)
make test              # run container smoke test
make run               # run the image interactively (amd64)
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Git](https://git-scm.com/) | latest | Version control |
| [Docker](https://www.docker.com/) | latest | Container runtime and buildx |
| [hadolint](https://github.com/hadolint/hadolint) | 2.14.0 | Dockerfile linting (auto-installed by `make lint`) |
| [act](https://github.com/nektos/act) | 0.2.87 | Run GitHub Actions locally (optional) |
| [nvm](https://github.com/nvm-sh/nvm) | 0.40.4 | Node.js for Renovate config validation (optional) |

Install all required dependencies:

```bash
make deps
```

## Available Make Targets

Run `make help` to see all available targets.

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build the dlib Docker image for all platforms |
| `make test` | Run container smoke test |
| `make lint` | Lint the Dockerfile with hadolint |
| `make static-check` | Composite quality gate (lint) |
| `make run` | Run the dlib Docker image interactively (amd64) |
| `make clean` | Remove build artefacts and temporary files |

### Docker

| Target | Description |
|--------|-------------|
| `make buildx-bootstrap` | Bootstrap multi-platform Docker buildx builder |
| `make image-run-amd64` | Run dlib image interactively (amd64) |
| `make image-run-arm64` | Run dlib image interactively (arm64) |
| `make image-run-armv7` | Run dlib image interactively (arm/v7) |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full CI pipeline (deps, static-check, build, test) |
| `make ci-run` | Run GitHub Actions workflow locally via [act](https://github.com/nektos/act) |

### Utilities

| Target | Description |
|--------|-------------|
| `make help` | List available tasks |
| `make deps` | Verify required toolchain dependencies |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-act` | Install act for local CI execution |
| `make release` | Create and push a new semver tag |
| `make tag-delete` | Delete a tag locally and from remote (TAG=vX.Y.Z) |
| `make renovate-bootstrap` | Install nvm and Node for Renovate |
| `make renovate-validate` | Validate Renovate configuration |

## Architecture

The build uses Docker Buildx with QEMU emulation to produce one image per platform:

- **Base**: `ubuntu:noble-20260217` pinned by digest (via `ARG BUILDER_IMAGE`)
- **Cross-build toolchains**: when building for `arm64`, the build stage installs `crossbuild-essential-arm64/armel/armhf` plus `libapparmor-dev` and `libseccomp-dev` for each architecture
- **DLib + deps**: `libdlib-dev`, OpenBLAS, BLAS, ATLAS, LAPACK, GSL CBLAS, GFortran, libjpeg, libpng, GTK3 development headers
- **Runtime user**: non-root `appuser` (uid 1000, gid 1000, home in `/home/appuser`)
- **Default CMD**: `tail -f /dev/null` — the image is a utility container; consumers `docker run` it with their own command or `-it ... /bin/bash`

On tag pushes (`v*`), CI builds and pushes all three platforms as a single multi-arch manifest to `ghcr.io/<owner>/dlib-docker`.

## CI/CD

GitHub Actions runs on every push to `main`, tag pushes `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **static-check** | push, PR, tags | Checkout, Static check (`make static-check` → hadolint) |
| **docker** | tag push (`v*`) | QEMU, Buildx, Log in to GHCR, Docker metadata, Build and push (multi-arch → `ghcr.io`) |
| **ci-pass** | always | Aggregates `static-check` + `docker` results for branch protection |

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date via platform branch automerge (squash strategy). A weekly `cleanup-runs.yml` workflow prunes old workflow runs and stale GitHub Actions caches.
