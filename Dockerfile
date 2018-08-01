FROM centos:7
MAINTAINER Chih-Hsuan Kuo <kuoe0.tw@gmail.com>


CMD ["--help"]
ENTRYPOINT ["ffmpeg"]

WORKDIR /work

ENV TARGET_VERSION=4.0 \
    LIBVA_VERSION=1.8.2 \
    LIBDRM_VERSION=2.4.80 \
    SRC=/usr \
    PKG_CONFIG_PATH=/usr/lib/pkgconfig

RUN yum install -y --enablerepo=extras epel-release yum-utils && \
    # Install libdrm
    yum install -y libdrm libdrm-devel && \
    # Install build dependencies
    build_deps="automake autoconf bzip2 \
                cmake freetype-devel gcc \
                gcc-c++ git libtool make \
                mercurial nasm pkgconfig \
                yasm zlib-devel" && \
    yum install -y ${build_deps}

# Build libva
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL https://www.freedesktop.org/software/vaapi/releases/libva/libva-${LIBVA_VERSION}.tar.bz2 | \
    tar -jx --strip-components=1 && \
    ./configure CFLAGS=' -O2' CXXFLAGS=' -O2' --prefix=${SRC} && \
    make && make install && \
    rm -rf ${DIR}

# Build libva-intel-driver
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL https://www.freedesktop.org/software/vaapi/releases/libva-intel-driver/intel-vaapi-driver-${LIBVA_VERSION}.tar.bz2 | \
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
RUN yum history -y undo last && \
    yum clean all

# Show ffmpeg info
RUN ffmpeg -buildconf
