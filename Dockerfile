ARG BUILDER_IMAGE="ubuntu:noble-20251001"

FROM ${BUILDER_IMAGE} AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG DLIB_VERSION=19.24
ARG GCC_VERSION=12.4.0

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update

RUN <<EOT
    if [ "${TARGETARCH}" == "amd64" ] || [ "${TARGETARCH}" == "arm64" ]; then

        dpkg --add-architecture arm64
        dpkg --add-architecture armel
        dpkg --add-architecture armhf

        DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y --no-install-recommends \
            crossbuild-essential-arm64 \
            crossbuild-essential-armel \
            crossbuild-essential-armhf

        DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y --no-install-recommends \
            libapparmor-dev:arm64 \
            libapparmor-dev:armel \
            libapparmor-dev:armhf \
            libseccomp-dev:arm64 \
            libseccomp-dev:armel \
            libseccomp-dev:armhf
    fi
EOT

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends build-essential cmake curl wget net-tools

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends \
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
    libdlib-dev
# https://launchpad.net/ubuntu/oracular/+package/libdlib-dev

# build GCC
#RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y --no-install-recommends \
#    curl wget net-tools \
#    cmake build-essential pkg-config \
#    libmpfr-dev libmpfr6 libmpc-dev libgmp-dev libisl-dev
#WORKDIR /opt
#RUN cd /opt && \
#    wget http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz && \
#    tar xf gcc-$GCC_VERSION.tar.gz && cd gcc-$GCC_VERSION && \
#    ./configure --disable-multilib --disable-libquadmath --disable-libquadmath-support --enable-languages=c,c++ && \
#    make -j$(grep -c processor /proc/cpuinfo) && make install

# build DLib
# https://github.com/imishinist/dlib/blob/master/19.21/buster/Dockerfile
#RUN mkdir /dlib && cd /dlib && curl -sLO http://dlib.net/files/dlib-$DLIB_VERSION.tar.bz2 && tar xf dlib-$DLIB_VERSION.tar.bz2
#RUN cd /dlib/dlib-$DLIB_VERSION && mkdir build && cd build \
#    && cmake .. && cmake -DDLIB_PNG_SUPPORT=ON -DDLIB_GIF_SUPPORT=ON -DDLIB_JPEG_SUPPORT=ON -DDLIB_NO_GUI_SUPPORT=ON .. \
#    && cmake --build . --config Release \
#    && make -j$(grep -c processor /proc/cpuinfo) \
#    && make install \
#    && rm -rf /dlib

#    && apt-get autoremove -y; apt-get clean; rm -rf /var/cache;

# Keep the container running
CMD ["tail", "-f", "/dev/null"]