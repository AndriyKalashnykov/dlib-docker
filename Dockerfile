ARG BUILDER_IMAGE="ubuntu:noble-20260217@sha256:186072bba1b2f436cbb91ef2567abca677337cfc786c86e107d25b7072feef0c"

FROM ${BUILDER_IMAGE} AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG DLIB_VERSION=20.0

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && \
    if [ "${TARGETARCH}" = "amd64" ] || [ "${TARGETARCH}" = "arm64" ]; then \
        dpkg --add-architecture arm64 && \
        dpkg --add-architecture armel && \
        dpkg --add-architecture armhf && \
        apt-get update && apt-get install -y --no-install-recommends \
            crossbuild-essential-arm64 \
            crossbuild-essential-armel \
            crossbuild-essential-armhf \
            libapparmor-dev:arm64 \
            libapparmor-dev:armel \
            libapparmor-dev:armhf \
            libseccomp-dev:arm64 \
            libseccomp-dev:armel \
            libseccomp-dev:armhf; \
    fi && \
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

# Keep the container running
CMD ["tail", "-f", "/dev/null"]
