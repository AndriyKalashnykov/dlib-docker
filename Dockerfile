ARG CROSS="true"
ARG DEBIAN_FRONTEND=noninteractive
ARG OS_IMAGE="debian:bookworm"
#ARG OS_IMAGE="ubuntu:24.10"

FROM ${OS_IMAGE} AS base

#RUN echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
#ARG APT_MIRROR
#RUN sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR:-deb.debian.org}/g" /etc/apt/sources.list \
# && sed -ri "s/(security).debian.org/${APT_MIRROR:-security.debian.org}/g" /etc/apt/sources.list

FROM base AS cross-true
ARG DEBIAN_FRONTEND
RUN dpkg --add-architecture arm64
RUN dpkg --add-architecture armel
RUN dpkg --add-architecture armhf

RUN --mount=type=cache,sharing=locked,id=moby-cross-true-aptlib,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=moby-cross-true-aptcache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    crossbuild-essential-arm64 \
    crossbuild-essential-armel \
    crossbuild-essential-armhf

FROM cross-true AS runtime-dev-cross-true
ARG DEBIAN_FRONTEND
# These crossbuild packages rely on gcc-<arch>, but this doesn't want to install
# on non-amd64 systems, so other architectures cannot crossbuild amd64.

RUN --mount=type=cache,sharing=locked,id=moby-cross-true-aptlib,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=moby-cross-true-aptcache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    libapparmor-dev:arm64 \
    libapparmor-dev:armel \
    libapparmor-dev:armhf \
    libseccomp-dev:arm64 \
    libseccomp-dev:armel \
    libseccomp-dev:armhf

FROM runtime-dev-cross-${CROSS} AS runtime-dev

ENV DLIB_VERSION=19.24

RUN apt-get update
RUN apt-get install -y build-essential cmake curl


RUN apt-get install -y \
    libopenblas-dev \
    libblas-dev \
    libatlas-base-dev \
    libgslcblas0 \
    libjpeg-dev \
    libpng-dev \
    liblapack-dev \
    gfortran \
    libx11-dev libgtk-3-dev \
    libjpeg62-turbo-dev

# http://mirrors.edge.kernel.org/ubuntu/pool/main/libj/libjpeg-turbo/
# https://packages.debian.org/buster/libjpeg62-turbo-dev
# RUN mkdir /libjpeg-turbo && cd /libjpeg-turbo && curl -sLO http://mirrors.edge.kernel.org/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8-dev_2.1.5-2ubuntu2_amd64.deb && apt-get install -y ./libjpeg-turbo8-dev_2.1.5-2ubuntu2_amd64.deb

# https://github.com/imishinist/dlib/blob/master/19.21/buster/Dockerfile
RUN mkdir /dlib && cd /dlib && curl -sLO http://dlib.net/files/dlib-${DLIB_VERSION}.tar.bz2 && tar xf dlib-${DLIB_VERSION}.tar.bz2
RUN cd /dlib/dlib-${DLIB_VERSION} && mkdir build && cd build && cmake .. && cmake -DDLIB_PNG_SUPPORT=ON -DDLIB_GIF_SUPPORT=ON -DDLIB_JPEG_SUPPORT=ON -DDLIB_NO_GUI_SUPPORT=ON --build . --config Release && make -j$(grep -c processor /proc/cpuinfo) && make install && rm -rf /dlib \
    apt-get autoremove -y; apt-get clean; rm -rf /var/cache; \
    rm /dlib/dlib-${DLIB_VERSION}.tar.bz2

# Keep the container running
CMD ["tail", "-f", "/dev/null"]