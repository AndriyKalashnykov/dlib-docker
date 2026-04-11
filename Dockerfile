# syntax=docker/dockerfile:1@sha256:4a43a54dd1fedceb30ba47e76cfcf2b47304f4161c0caeac2db1c61804ea3c91

FROM ubuntu:noble-20260217@sha256:186072bba1b2f436cbb91ef2567abca677337cfc786c86e107d25b7072feef0c

ARG DEBIAN_FRONTEND=noninteractive
ARG DLIB_VERSION=20.0.1

# dlib build + runtime dependencies (BLAS/LAPACK/image/GUI). Each platform
# build runs natively under QEMU via docker buildx --platform, so apt pulls
# packages native to the target arch.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential cmake \
        ca-certificates curl wget net-tools \
        libopenblas-dev \
        libblas-dev \
        libatlas-base-dev \
        libgslcblas0 \
        libjpeg-dev \
        libpng-dev \
        liblapack-dev \
        gfortran libgfortran5 \
        libx11-dev libgtk-3-dev \
        libjpeg-turbo8-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Build dlib from source at the pinned upstream tag. DLIB_VERSION must be
# a released tag on davisking/dlib (e.g. "20.0.1", "19.24.9").
#
# dlib's CMakeLists does not emit both libdlib.so AND libdlib.a from a single
# configure, so we configure+build+install twice with different BUILD_SHARED_LIBS
# settings. Both artifacts land in /usr/local/lib side-by-side, which lets
# downstream consumers choose dynamic OR static linking. Static linking is the
# hard requirement for go-face-recognition's -extldflags -static build.
#
# CMAKE_POSITION_INDEPENDENT_CODE=ON on the static build makes libdlib.a PIC-safe
# so it can be linked into shared objects and Go PIE binaries without runtime
# relocations errors.
RUN set -eux; \
    curl -fsSL "https://github.com/davisking/dlib/archive/refs/tags/v${DLIB_VERSION}.tar.gz" -o /tmp/dlib.tar.gz; \
    tar -xzf /tmp/dlib.tar.gz -C /tmp; \
    # --- pass 1: shared library (libdlib.so + headers + cmake package) ---
    cmake -S "/tmp/dlib-${DLIB_VERSION}" -B "/tmp/dlib-${DLIB_VERSION}/build-shared" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DDLIB_USE_BLAS=ON \
        -DDLIB_USE_LAPACK=ON; \
    cmake --build "/tmp/dlib-${DLIB_VERSION}/build-shared" -j"$(nproc)"; \
    cmake --install "/tmp/dlib-${DLIB_VERSION}/build-shared"; \
    # --- pass 2: static archive (libdlib.a) ---
    cmake -S "/tmp/dlib-${DLIB_VERSION}" -B "/tmp/dlib-${DLIB_VERSION}/build-static" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DDLIB_USE_BLAS=ON \
        -DDLIB_USE_LAPACK=ON; \
    cmake --build "/tmp/dlib-${DLIB_VERSION}/build-static" -j"$(nproc)"; \
    cmake --install "/tmp/dlib-${DLIB_VERSION}/build-static"; \
    ldconfig; \
    rm -rf "/tmp/dlib.tar.gz" "/tmp/dlib-${DLIB_VERSION}"

# /usr/local/lib is in /etc/ld.so.conf.d/libc.conf (so the runtime linker finds
# libdlib.so via ldconfig), but it is NOT in the *static* linker's compiled-in
# default search path on Debian/Ubuntu. Exporting LIBRARY_PATH here makes
# `ld -ldlib` resolve to /usr/local/lib/libdlib.a during downstream builds
# without needing every downstream Dockerfile to duplicate this knowledge.
ENV LIBRARY_PATH=/usr/local/lib

RUN userdel -r ubuntu 2>/dev/null || true && \
    groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser
USER appuser

CMD ["tail", "-f", "/dev/null"]
