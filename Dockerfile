# syntax=docker/dockerfile:1@sha256:4a43a54dd1fedceb30ba47e76cfcf2b47304f4161c0caeac2db1c61804ea3c91

FROM ubuntu:noble-20260217@sha256:186072bba1b2f436cbb91ef2567abca677337cfc786c86e107d25b7072feef0c AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG DLIB_VERSION=20.0

# Each platform build runs natively under QEMU (via docker buildx --platform),
# so apt pulls packages native to the target arch. No cross-compilation needed.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential cmake curl wget net-tools \
        libopenblas-dev \
        libblas-dev \
        libatlas-base-dev \
        libgslcblas0 \
        libjpeg-dev \
        libpng-dev \
        liblapack-dev \
        gfortran libgfortran5 \
        libx11-dev libgtk-3-dev \
        libjpeg-turbo8-dev \
        libdlib-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN userdel -r ubuntu 2>/dev/null || true && \
    groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser
USER appuser

# Keep the container running
CMD ["tail", "-f", "/dev/null"]
