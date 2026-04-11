[![CI](https://github.com/AndriyKalashnykov/dlib-docker/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/dlib-docker/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/AndriyKalashnykov/dlib-docker)](https://github.com/AndriyKalashnykov/dlib-docker/releases/latest)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/dlib-docker.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/dlib-docker/)
[![License: CC0](https://img.shields.io/badge/License-CC0-brightgreen.svg)](https://creativecommons.org/publicdomain/zero/1.0/)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/dlib-docker)

# dlib-docker

A hardened, multi-architecture **Ubuntu 24.04 base image** that ships [dlib](https://github.com/davisking/dlib) — the C++ machine learning and computer vision toolkit — compiled from source at a pinned upstream release tag and installed under `/usr/local`. It exists so downstream projects that wrap or link against dlib can skip the 10–30 minute cmake compile cost on every CI run while still getting deterministic, digest-pinned, and cosign-signed provenance on every bit that lands in their final image.

The image is the **root** of a three-repo build chain: a `FROM ghcr.io/andriykalashnykov/dlib-docker:<tag>@<digest>` line in any downstream Dockerfile inherits a fully prepared C++ toolchain with dlib, BLAS/LAPACK, libjpeg-turbo, libpng, X11, and GTK3 already in place, plus both dynamic and static variants of `libdlib` side-by-side so consumers can pick their preferred linking mode without rebuilding.

## What's in the image

Everything a downstream `FROM` inherits, in addition to the `ubuntu:noble` base:

- **Both `libdlib.so` AND `libdlib.a`** under `/usr/local/lib/`. dlib is built **twice**: once with `-DBUILD_SHARED_LIBS=ON` (shared), once with `-DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON` (static + PIC). Upstream `dlib/CMakeLists.txt` can't emit both from a single configure, and downstream projects like [`go-face-recognition`](https://github.com/AndriyKalashnykov/go-face-recognition) need `libdlib.a` specifically to produce a fully-static CGo binary via `-extldflags -static -ldlib`. The two-pass build pays the compile cost once, here, so every downstream consumer gets both options for free.
- **Full dlib C++ headers** (`/usr/local/include/dlib/…`), the CMake package config (`/usr/local/lib/cmake/dlib/`), and the pkg-config file (`/usr/local/lib/pkgconfig/dlib-1.pc`).
- **All dlib build-time + runtime dependencies** preinstalled from apt: OpenBLAS, BLAS, ATLAS, LAPACK, libjpeg-turbo, libpng, X11, GTK3, gfortran; plus `build-essential`, `cmake`, `ca-certificates`, and `curl`/`wget` for downstream compiles.
- **`ENV LIBRARY_PATH=/usr/local/lib`** so downstream `ld -ldlib` resolves the static archive without every downstream Dockerfile having to duplicate that knowledge. `/usr/local/lib` is in `/etc/ld.so.conf.d/libc.conf` for the runtime linker — so `dlopen` finds `libdlib.so` — but it is **not** in the static linker's compiled-in default search path on Debian/Ubuntu, which is why the env var is needed.
- **Non-root runtime user** `appuser` (UID 1000, GID 1000). K8s restricted-pod-security compatible out of the box. Downstream builder stages that need to write apt / module / go build caches should add `USER root` at the top of their builder stage (see [Using as a builder image](#using-as-a-builder-image) below).

## Multi-architecture + versioning convention

Every git tag `v<X.Y.Z>` publishes a **single multi-arch manifest list** at `ghcr.io/andriykalashnykov/dlib-docker:<X.Y.Z>` covering `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Each platform is built natively inside a `docker buildx` QEMU environment — `apt` pulls target-arch packages and the dlib compile produces target-arch binaries without any cross-compile toolchain. On top of the full version, CI also publishes the semver rollup tags `<X.Y>`, `<X>`, and `latest`.

**Project convention: the git tag matches the dlib release it ships.** `v19.24.9` ships dlib 19.24.9; `v20.0.1` ships dlib 20.0.1. Cutting a new release is a single-line bump to `DLIB_VERSION` in the `Makefile` followed by `make release NEWTAG=vX.Y.Z` — CI extracts `DLIB_VERSION` from the Makefile at build time and downloads that exact upstream dlib tarball.

## Who should use this image

Any C++ or CGo project that wants to build against dlib without compiling it from source on every downstream CI run. The canonical consumers in this author's image chain are:

1. **[`AndriyKalashnykov/go-face`](https://github.com/AndriyKalashnykov/go-face)** — adds the Go toolchain and the `go-face` CGo bindings on top, publishing `ghcr.io/andriykalashnykov/go-face/dlib19:<tag>` and `ghcr.io/andriykalashnykov/go-face/dlib20:<tag>` (one image per active dlib major lineage). go-face's CI has its own matrix driven by `.dlib-versions.json` that pins specific dlib-docker digests per lineage.
2. **[`AndriyKalashnykov/go-face-recognition`](https://github.com/AndriyKalashnykov/go-face-recognition)** — a face-recognition CLI built on `go-face`, statically linked against `libdlib.a` from this image. Its CI matrix builds `linux/amd64` + `linux/arm64` + `linux/arm/v7` runtime images plus pre-built binary tarballs published as signed GitHub Release assets.

But the image is intentionally **general purpose**. If your project links against `-ldlib` and wants a reproducible Ubuntu-based build environment with dlib + BLAS + image libraries preconfigured, this is the image for you.

## Using as a builder image

Minimal template for a downstream `Dockerfile` that builds a C++ or CGo binary on top of this image:

```dockerfile
# Pin the tag AND the digest for reproducibility. Renovate can keep the
# digest fresh automatically via a docker-image manager.
ARG BUILDER_IMAGE="ghcr.io/andriykalashnykov/dlib-docker:20.0.1@sha256:<current-digest>"

FROM ${BUILDER_IMAGE} AS builder

# This image drops to USER appuser (UID 1000) at the end of its own
# Dockerfile for a safe non-root runtime default. In a downstream builder
# stage you almost always need root — to apt-get install extra packages,
# to write Go module or cmake build caches into /root or /usr/local, etc.
# Reset it here. The runtime stage below can drop back to non-root.
USER root

WORKDIR /app
COPY . .

# Dynamic link — runtime depends on libdlib.so from this image chain:
#   RUN g++ -std=c++17 my_app.cpp -o my_app -ldlib -ljpeg -lpng -lopenblas
#
# Static link — fully self-contained binary, no libdlib.so at runtime
# (required for Go CGo builds with -extldflags -static):
#   RUN g++ -std=c++17 my_app.cpp -o my_app -static -ldlib ...
#
# LIBRARY_PATH=/usr/local/lib is inherited from this image, so no -L
# flag is needed to find either libdlib.so or libdlib.a.
RUN ./build.sh

# Small runtime stage. Non-root UID, apk upgrade for CVEs.
FROM alpine:3.23.3 AS runtime
RUN apk --no-cache upgrade && adduser -u 10001 -S -D app
WORKDIR /app
COPY --from=builder /app/my_app .
USER 10001
CMD ["/app/my_app"]
```

See [`Dockerfile.go-face` in the go-face-recognition repo](https://github.com/AndriyKalashnykov/go-face-recognition/blob/main/Dockerfile.go-face) for a worked example that statically links a CGo binary against this image's `libdlib.a`.

## Summary table

| Component | Technology |
|-----------|------------|
| Base Image | `ubuntu:noble-20260217` (digest-pinned by full sha256) |
| Bundled C++ library | [`davisking/dlib`](https://github.com/davisking/dlib) — built from source at `v$DLIB_VERSION` |
| dlib link variants | `libdlib.so` + `libdlib.so.$DLIB_VERSION` (shared) **and** `libdlib.a` (static, PIC-safe) |
| dlib install prefix | `/usr/local` (libs, headers, cmake config, pkg-config) |
| Build-time deps (apt) | `build-essential`, `cmake`, OpenBLAS, BLAS, ATLAS, LAPACK, libjpeg-turbo, libpng, X11, GTK3, gfortran |
| Platforms | `linux/amd64`, `linux/arm64`, `linux/arm/v7` (single multi-arch manifest list) |
| Runtime user | Non-root `appuser` (UID 1000) |
| Static-link env | `LIBRARY_PATH=/usr/local/lib` exported so `ld -ldlib` resolves `libdlib.a` |
| Container runtime | Docker + Buildx (multi-platform QEMU builder) |
| CI/CD | GitHub Actions → GHCR multi-arch push → Cosign keyless OIDC signing → GitHub Release |
| Image signing | [Cosign](https://docs.sigstore.dev/cosign/overview/) keyless (Sigstore Fulcio → Rekor, tag-pushes only) |
| Dockerfile linter | [hadolint](https://github.com/hadolint/hadolint) 2.14.0 |
| Dependency updates | [Renovate](https://docs.renovatebot.com/) with branch automerge + squash |

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

The Dockerfile is a **single-stage build** (dlib is the only artefact, there's no cross-compile or runtime slice). Docker Buildx with QEMU emulation produces one image per target platform; each platform build runs natively inside its own emulated environment, so apt and the dlib compile both produce target-native binaries without any cross-compile toolchain.

- **Base image**: `ubuntu:noble-20260217` pinned by the full `sha256` manifest digest for reproducibility. Renovate keeps the digest fresh.
- **Build-time apt installs** (one layer, `--no-install-recommends`, `/var/lib/apt/lists/*` cleaned up): `build-essential`, `cmake`, OpenBLAS, BLAS, ATLAS, LAPACK, GSL CBLAS, gfortran + libgfortran5, libjpeg-dev + libjpeg-turbo8-dev, libpng-dev, libx11-dev, libgtk-3-dev, plus `ca-certificates`, `curl`, `wget`, `net-tools` for the dlib download and interactive use.
- **dlib source download**: `curl -fsSL https://github.com/davisking/dlib/archive/refs/tags/v${DLIB_VERSION}.tar.gz` → `tar -xzf` into `/tmp`. `DLIB_VERSION` is a build-arg fed from the `Makefile`.
- **dlib build (two passes)** — upstream's `CMakeLists.txt` cannot emit shared and static artefacts from a single configure, so the Dockerfile runs the full `cmake → cmake --build → cmake --install` cycle twice:
  1. **Shared pass** — `-DBUILD_SHARED_LIBS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DDLIB_USE_BLAS=ON -DDLIB_USE_LAPACK=ON`. Installs `libdlib.so`, `libdlib.so.${DLIB_VERSION}`, the dlib headers, the CMake package config, and the pkg-config file.
  2. **Static pass** — `-DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DDLIB_USE_BLAS=ON -DDLIB_USE_LAPACK=ON`. Installs `libdlib.a` alongside the already-installed shared artefacts. `CMAKE_POSITION_INDEPENDENT_CODE=ON` on this pass makes the static archive PIC-safe so it can be linked into shared objects and Go PIE binaries without relocation errors.
  3. **`ldconfig`** refreshes `/etc/ld.so.cache` so `dlopen("libdlib.so")` works at runtime.
  4. `/tmp/dlib.tar.gz` and the `/tmp/dlib-${DLIB_VERSION}` source tree are removed to keep the final layer small.
- **Output under `/usr/local`** (what downstream consumers inherit):
  - `lib/libdlib.so`, `lib/libdlib.so.${DLIB_VERSION}` — shared library
  - `lib/libdlib.a` — static archive, PIC-safe
  - `include/dlib/…` — full C++ headers
  - `lib/cmake/dlib/…` — CMake package config
  - `lib/pkgconfig/dlib-1.pc` — pkg-config metadata
- **`ENV LIBRARY_PATH=/usr/local/lib`** — exported so the GNU linker finds `libdlib.a` when downstream builds pass `-ldlib` under `-static`. Without this, Debian/Ubuntu's static linker default search path would skip `/usr/local/lib` and fail with `/usr/bin/ld: cannot find -ldlib` even though the archive is installed. The runtime linker is unaffected — it reads `/etc/ld.so.conf.d/libc.conf` independently.
- **Runtime user**: non-root `appuser` (UID 1000, GID 1000, home in `/home/appuser`). The default `ubuntu` user shipped by Noble's base image is `userdel -r`'d first so `appuser` can take UID 1000 cleanly. Downstream builder stages that need root should add `USER root` immediately after their `FROM` line.
- **Default `CMD`**: `tail -f /dev/null`. The image is a utility container — consumers `docker run` it with their own command, or `-it ... /bin/bash` for interactive debugging.

On tag pushes (`v*`), CI builds and pushes all three platforms as a single multi-arch manifest to `ghcr.io/andriykalashnykov/dlib-docker`, creates a matching GitHub Release with auto-generated notes, and publishes the bare-semver rollup tag set: `${DLIB_VERSION}`, `<major>.<minor>`, `<major>`, `latest`. Each published `tag@digest` is signed with cosign keyless OIDC (Sigstore Fulcio → Rekor) so downstream consumers can verify provenance with no pre-shared key.

## CI/CD

GitHub Actions runs on every push to `main`, tag pushes `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **static-check** | push, PR, tags | Checkout, Static check (`make static-check` → hadolint + trivy-fs) |
| **docker** | tag push (`v*`) | QEMU, Buildx, Build image for scan, Trivy image scan, Smoke test, Log in to GHCR, Docker metadata, Build and push (multi-arch), Install cosign, Sign image with cosign, Create GitHub Release |
| **ci-pass** | always | Aggregates `static-check` + `docker` results for branch protection (catches `failure` and `cancelled`) |

### Pre-push image hardening

The `docker` job runs the following gates **before** any image is pushed to `ghcr.io`. Any failure blocks the release.

| # | Gate | Catches | Tool |
|---|---|---|---|
| 1 | Build local single-arch image | Build regressions on the runner architecture — including cmake compile failures from upstream dlib source changes, missing apt packages, and cross-version incompatibilities | `docker/build-push-action` with `load: true` |
| 2 | **Trivy image scan** (CRITICAL/HIGH blocking) | CVEs in the Ubuntu base image, apt packages, and the compiled dlib layer — things a filesystem scan cannot see because they live inside the built image | `aquasecurity/trivy-action` with `image-ref:` |
| 3 | **Smoke test** | The compiled dlib is actually installed and **both** link variants are present: `/usr/local/include/dlib/matrix.h` (headers), `/usr/local/lib/libdlib.so*` (shared), and `/usr/local/lib/libdlib.a` (static archive — regression guard for the two-pass cmake build added 2026-04-11) | `docker run` + header/lib/archive presence probe |
| 4 | Multi-arch build + push | Cross-compile regressions for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` — each platform built natively under QEMU. Publishes the single multi-arch manifest list to GHCR | `docker/build-push-action` with `platforms:` |
| 5 | **Cosign keyless OIDC signing** | Tampered or unsigned images — every published `tag@digest` gets a Sigstore signature keyed to the GitHub Actions workflow's OIDC identity, verifiable with no pre-shared key | `sigstore/cosign-installer` + `cosign sign --yes <tag>@<digest>` |

Buildkit in-manifest attestations (`provenance` + `sbom`) are disabled so the image index stays free of `unknown/unknown` platform entries — this lets the GHCR Packages UI render the "OS / Arch" tab for the multi-arch manifest. Cosign keyless signing provides the Sigstore signature for supply-chain verification without in-manifest attestations.

Verify a published image's signature:

```bash
cosign verify ghcr.io/andriykalashnykov/dlib-docker:20.0.1 \
  --certificate-identity-regexp 'https://github\.com/AndriyKalashnykov/dlib-docker/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date via platform branch automerge (squash strategy). A weekly `cleanup-runs.yml` workflow prunes old workflow runs and stale GitHub Actions caches.
