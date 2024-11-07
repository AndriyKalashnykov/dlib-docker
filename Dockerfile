ARG OS_IMAGE="debian:bookworm"
ARG DEBIAN_FRONTEND=noninteractive

FROM ${OS_IMAGE} AS builder

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y --no-install-recommends \
    curl wget net-tools \
    cmake build-essential pkg-config \
    libmpfr-dev libmpfr6 libmpc-dev libgmp-dev libisl-dev

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y \
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

ENV GCC_VERSION=11.5.0

WORKDIR /opt

RUN cd /opt && \
    wget http://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz && \
    tar xf gcc-${GCC_VERSION}.tar.gz && \
    cd gcc-${GCC_VERSION} && \
    ./configure --disable-libquadmath --disable-libquadmath-support --enable-languages=c,c++ && \
    make -j$(grep -c processor /proc/cpuinfo) && \
    make install

ENV DLIB_VERSION=19.24

# https://github.com/imishinist/dlib/blob/master/19.21/buster/Dockerfile
RUN mkdir /dlib && cd /dlib && curl -sLO http://dlib.net/files/dlib-${DLIB_VERSION}.tar.bz2 && tar xf dlib-${DLIB_VERSION}.tar.bz2
RUN cd /dlib/dlib-${DLIB_VERSION} && mkdir build && cd build \
    && cmake .. && cmake -DDLIB_PNG_SUPPORT=ON -DDLIB_GIF_SUPPORT=ON -DDLIB_JPEG_SUPPORT=ON -DDLIB_NO_GUI_SUPPORT=ON .. \
    && cmake --build . --config Release \
    && make -j$(grep -c processor /proc/cpuinfo) \
    && make install \
    && rm -rf /dlib

#    && apt-get autoremove -y; apt-get clean; rm -rf /var/cache;

# Keep the container running
CMD ["tail", "-f", "/dev/null"]