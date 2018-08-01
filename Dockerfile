FROM ubuntu:18.04
MAINTAINER Chih-Hsuan Kuo <kuoe0.tw@gmail.com>


CMD ["--help"]
ENTRYPOINT ["ffmpeg"]

WORKDIR /work

ENV TARGET_VERSION=4.0 \
    LIBVA_VERSION=2.2.0 \
    SRC=/usr

RUN apt update
RUN apt install -y libdrm2 libdrm-dev && \
# Install build dependencies
    build_deps="automake autoconf bzip2 \
                cmake curl libfreetype6-dev \
                gcc g++ git libtool make \
                mercurial nasm pkg-config \
                yasm zlib1g-dev" && \
    apt install -y ${build_deps}

# Build libva
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/intel/libva/releases/download/${LIBVA_VERSION}/libva-${LIBVA_VERSION}.tar.bz2" | \
    tar -jx --strip-components=1 && \
    ./configure CFLAGS=' -O3' CXXFLAGS=' -O3' --prefix=${SRC} && \
    make && make install && \
    rm -rf ${DIR}

# Build libva-intel-driver
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL https://www.freedesktop.org/software/vaapi/releases/libva-intel-driver/intel-vaapi-driver-${LIBVA_VERSION}.tar.bz2 | \
    curl -sL "https://github.com/intel/intel-vaapi-driver/releases/download/${LIBVA_VERSION}/intel-vaapi-driver-${LIBVA_VERSION}.tar.bz2" | \
    tar -jx --strip-components=1 && \
    ./configure && \
    make && make install && \
    rm -rf ${DIR}

# Build ffmpeg
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL http://ffmpeg.org/releases/ffmpeg-${TARGET_VERSION}.tar.gz | \
    tar -zx --strip-components=1 && \
    ./configure \
        --prefix=${SRC} \
        --enable-small \
        --enable-gpl \
        --enable-vaapi \
        --disable-doc \
        --disable-debug && \
    make && make install && \
    make distclean && \
    hash -r && \
    rm -rf ${DIR}

# Cleanup build dependencies and temporary files
RUN apt purge -y ${build_deps} && \
    apt -y autoclean

# Show ffmpeg info
RUN ffmpeg -buildconf
