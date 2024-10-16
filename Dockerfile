# https://hub.docker.com/_/alpine/tags
FROM alpine:3.20.3  AS base

RUN apk add --no-cache ca-certificates

ENV DLIB_VERSION=19.24

RUN set -eux; \
        apk add --no-cache --virtual .build-deps \
            gcc \
            g++ \
            cmake \
            make \
            libc-dev \
            linux-headers \
            giflib-dev \
            jpeg \
            openblas \
            openblas-dev \
            liblapack \
        ; \
        wget -c -q "https://github.com/davisking/dlib/archive/v${DLIB_VERSION}.tar.gz"; \
        tar xf "v${DLIB_VERSION}.tar.gz"; \
        mkdir -p dlib-${DLIB_VERSION}/build; \       
        ( \
          cd dlib-${DLIB_VERSION}/build; \
          cmake -DDLIB_PNG_SUPPORT=ON -DDLIB_GIF_SUPPORT=ON -DDLIB_JPEG_SUPPORT=ON -DDLIB_NO_GUI_SUPPORT=ON ..; \
          make -j4; \
          make install; \
        ); \
        apk del --no-network .build-deps; \
        rm -rf /usr/local/lib64/cmake; \
        rm -rf /dlib-${DLIB_VERSION}; \
        rm v${DLIB_VERSION}.tar.gz