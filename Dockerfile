FROM centos:7
MAINTAINER Chih-Hsuan Kuo <kuoe0.tw@gmail.com>


CMD ["ffmpeg", "--help"]

WORKDIR /work

# Setup build environment and packages version
ENV FFMPEG_VERSION=4.0 \
    INTEL_HYBRID_DRIVER_VERSION=1.0.2 \
    LIBFDK_AAC_VERSION=0.1.6 \
    LIBOGG_VERSION=1.3.3 \
    LIBVA_VERSION=2.2.0 \
    LIBVORBIS_VERSION=1.3.6 \
    LIBVPX_VERSION=1.7.0 \
    LIBX265_VERSION=2.8 \
    NASM_VERSION=2.13.03 \
    PREFIX=/usr \
    PKG_CONFIG_PATH=/usr/lib/pkgconfig

ARG MAKE_JOBS=1

# Install necessary packages
RUN yum install -y --enablerepo=extras epel-release yum-utils && \
    # Install HWaccel dependencies
    yum install -y libdrm-devel libX11-devel && \
    # Install build dependencies
    build_deps="automake autoconf bzip2 cmake freetype-devel gcc \
                gcc-c++ git libtool make mercurial pkgconfig which \
                yasm zlib-devel" && \
    yum install -y ${build_deps}

#######################
# VA-API Dependencies #
#######################

# Build libva (implementation for VA-API)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/intel/libva/releases/download/${LIBVA_VERSION}/libva-${LIBVA_VERSION}.tar.bz2" | \
    tar -jx --strip-components=1 && \
    ./configure --prefix=${PREFIX} CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    rm -rf ${DIR}

# Build cmrt (TODO: for what?)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/intel/cmrt/archive/1.0.6.tar.gz" | \
    tar -zx --strip-components=1 && \
    ./autogen.sh && \
    ./configure --prefix=${PREFIX} CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    rm -rf ${DIR}

# Build intel-hybrid-driver (VA-API for vp8 and vp9)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/01org/intel-hybrid-driver/archive/${INTEL_HYBRID_DRIVER_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    ./autogen.sh && \
    ./configure --prefix=${PREFIX} CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    rm -rf ${DIR}

# Build intel-vaapi-driver (VA-API user mode driver for Intel GEN Graphics family)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    # Use the version for intel-vaapi-driver as same as libva
    curl -sL "https://github.com/intel/intel-vaapi-driver/releases/download/${LIBVA_VERSION}/intel-vaapi-driver-${LIBVA_VERSION}.tar.bz2" | \
    tar -jx --strip-components=1 && \
    ./configure --prefix=${PREFIX} CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    rm -rf ${DIR}

# (optional) Build libva-utils (to have `vainfo` command)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    ldconfig && \
    # Use the version for libva-utils as same as libva
    curl -sL "https://github.com/intel/libva-utils/releases/download/${LIBVA_VERSION}/libva-utils-${LIBVA_VERSION}.tar.bz2" | \
    tar -jx --strip-components=1 && \
    ./configure --prefix=${PREFIX} CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    rm -rf ${DIR}

##########################################
# (optional) Software Codec Dependencies #
##########################################

# Build nasm (for compiling libx264 and libx265)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    ./configure --prefix=${PREFIX} \
                --bindir=${PREFIX}/bin \
                CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && make distclean && \
    rm -rf ${DIR}

# Build libx264
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    # Get the last stable version
    # XXX: Maybe should specify a version
    curl -sL "ftp://ftp.videolan.org/pub/videolan/x264/snapshots/last_stable_x264.tar.bz2" | \
    tar -jx --strip-components=1 && \
    ./configure --prefix=${PREFIX} \
                --bindir=${PREFIX}/bin \
                --enable-pic \
                --enable-shared \
                CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && make distclean && \
    rm -rf ${DIR}

# Build libx265
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://bitbucket.org/multicoreware/x265/downloads/x265_${LIBX265_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    cd build/linux && \
    cmake -G "Unix Makefiles" \
          -DCMAKE_INSTALL_PREFIX=${PREFIX} \
          -DENABLE_SHARED:bool=on \
          ../../source && \
    make -j${MAKE_JOBS} && make install && make clean && \
    rm -rf ${DIR}


# Build libfdk-acc
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/mstorsjo/fdk-aac/archive/v${LIBFDK_AAC_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    autoreconf -fiv && \
    ./configure --prefix=${PREFIX} CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && make distclean && \
    rm -rf ${DIR}

# Build libvpx
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/webmproject/libvpx/archive/v${LIBVPX_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    ./configure --prefix=${PREFIX} \
                --enable-multi-res-encoding \
                --enable-onthefly-bitpacking \
                --enable-postproc \
                --enable-realtime-only \
                --enable-runtime-cpu-detect \
                --enable-vp8 \
                --enable-vp9 \
                --enable-vp9-highbitdepth \
                --enable-vp9-postproc \
                --enable-webm-io \
                --cpu=native \
                --as=nasm && \
    make -j${MAKE_JOBS} && make install && \
    make clean && make distclean && \
    rm -rf ${DIR}

# Build libogg (libvorbis dependency)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "http://downloads.xiph.org/releases/ogg/libogg-${LIBOGG_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    ./configure --prefix=${PREFIX} CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    rm -rf ${DIR}

# Build libvorbis
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/xiph/vorbis/archive/v${LIBVORBIS_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    ./autogen.sh && \
    ./configure --enable-static --prefix=${PREFIX} && \
    ./configure --prefix=${PREFIX} \
                --enable-shared \
                CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    make clean && make distclean && \
    rm -rf ${DIR}

################
# Build ffmpeg #
################

RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" | \
    tar -zx --strip-components=1 && \
    ./configure --prefix=${PREFIX} \
                # optimize for size rather than speed
                --enable-small \
                --disable-doc \
                --disable-debug \

                # HWaccel codecs
                --enable-vaapi \

                # Software codecs
                # change license to GPL because libx264 uses GPL (ffmpeg is LGPL)
                --enable-gpl \
                --enable-libfdk-aac \
                --enable-libvorbis \
                --enable-libvpx \
                --enable-libx264 \
                --enable-libx265 \
                --enable-nonfree && \
    make -j${MAKE_JOBS} && make install && make distclean && \
    hash -r && \
    rm -rf ${DIR}

# Cleanup build dependencies and temporary files
RUN yum history -y undo last && \
    yum clean all

# Show ffmpeg info
RUN ffmpeg -buildconf
