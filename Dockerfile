FROM centos:7
MAINTAINER Chih-Hsuan Kuo <kuoe0.tw@gmail.com>


CMD ["ffmpeg", "--help"]

WORKDIR /work

# Packages Version
ENV CMRT_VERSION=1.0.6 \
    INTEL_HYBRID_DRIVER_VERSION=1.0.2 \
    INTEL_MEDIA_SDK_VERSION=MediaSDK-2018-Q2.1 \
    LIBFDK_AAC_VERSION=0.1.6 \
    LIBOGG_VERSION=1.3.3 \
    LIBVA_VERSION=2.1.0 \
    LIBVORBIS_VERSION=1.3.6 \
    LIBVPX_VERSION=1.7.0 \
    LIBX265_VERSION=2.8 \
    NASM_VERSION=2.13.03 \
    QSV_FFMPEG_VERSION=qsv-3.4.1.0

# Build Environment
ENV PREFIX=/usr \
    PKG_CONFIG_PATH=/usr/lib/pkgconfig \
    INTEL_MEDIA_SDK_PATH=/opt/intel/mediasdk \
    LIBMFX_INCLUDE=/opt/intel/mediasdk/include/mfx \
    LIBMFX_PC=/usr/lib64/pkgconfig/libmfx.pc

ARG MAKE_JOBS=1

# Install necessary packages
RUN yum install -y --enablerepo=extras epel-release yum-utils && \
        # Install HWaccel dependencies
    yum install -y libdrm-devel libX11-devel && \
    # Install build dependencies
    build_deps="automake autoconf bzip2 cmake curl freetype-devel \
                gcc gcc-c++ git libtool make mercurial pkgconfig \
                redhat-lsb yasm zlib-devel" && \
    yum install -y ${build_deps}

###############################
# Software Codec Dependencies #
###############################

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
    ./configure --prefix=${PREFIX} \
                --enable-shared \
                CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    make clean && make distclean && \
    rm -rf ${DIR}

#######################
# VA-API Dependencies #
#######################

# Build libva (implementation for VA-API)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/intel/libva/releases/download/${LIBVA_VERSION}/libva-${LIBVA_VERSION}.tar.bz2" | \
    tar -jx --strip-components=1 && \
    # XXX: Need to put libva to /usr/lib64.
    #      Because i965_dri.so would be in /usr/lib64,
    #      we also put libva to /usr/lib64.
    ./configure --prefix=${PREFIX} \
                --libdir=${PREFIX}/lib64 \
                CFLAGS=' -O2' CXXFLAGS=' -O2' && \
    make -j${MAKE_JOBS} && make install && \
    rm -rf ${DIR}

# Build cmrt (TODO: for what?)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL "https://github.com/intel/cmrt/archive/${CMRT_VERSION}.tar.gz" | \
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
    # XXX: Need to put i965_drv_video.so to /usr/lib64
    #      Because ffmpeg will search i965_drv_video.so in /usr/lib64,
    #      we also put i965_drv_video.so to /usr/lib64.
    ./configure --prefix=${PREFIX} \
                --libdir=${PREFIX}/lib64 \
                CFLAGS=' -O2' CXXFLAGS=' -O2' && \
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

# Build Intel Media SDK (needed for libmfx)
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    mkdir msdk && cd msdk && \
    curl -sL "https://github.com/Intel-Media-SDK/MediaSDK/releases/download/${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz" | \
    tar -xz --strip-components=1 && \
    ./install_media.sh && \
    # TODO: Need to figure out which files can be deleted
    # Remove unwanted files.
    # rm -r ${INTEL_MEDIA_SDK_PATH}/include \
    #       ${INTEL_MEDIA_SDK_PATH}/lib64/pkgconfig \
    #       ${INTEL_MEDIA_SDK_PATH}/lib64/*.a \
    #       ${INTEL_MEDIA_SDK_PATH}/plugins/plugins_eval.cfg \
    find ${INTEL_MEDIA_SDK_PATH}/samples -delete && \
    find ${INTEL_MEDIA_SDK_PATH} && \
    # TODO: Need to figure out which symbols can be deleted
    # Strip symbols.
    # strip -s /opt/intel/mediasdk/*/*.so && \
    rm -rf ${DIR}

# Make libmfx
RUN mkdir ${LIBMFX_INCLUDE} && \
    mv $(dirname ${LIBMFX_INCLUDE})/*.h ${LIBMFX_INCLUDE} && \
    # Write pkgconfig file for libmfx
    touch ${LIBMFX_PC} && \
    echo "prefix=${INTEL_MEDIA_SDK_PATH}"                                                     >> ${LIBMFX_PC} && \
    echo "exec_prefix=${INTEL_MEDIA_SDK_PATH}"                                                >> ${LIBMFX_PC} && \
    echo "libdir=${INTEL_MEDIA_SDK_PATH}/lib/lin_x64"                                         >> ${LIBMFX_PC} && \
    echo "includedir=${INTEL_MEDIA_SDK_PATH}/include"                                         >> ${LIBMFX_PC} && \
    echo ""                                                                                   >> ${LIBMFX_PC} && \
    echo "Name: libmfx"                                                                       >> ${LIBMFX_PC} && \
    echo "Description: Intel Media Server Studio SDK"                                         >> ${LIBMFX_PC} && \
    # TODO: Maybe should grep from ${INTEL_MEDI_SDK_PATH}/lib64/pkgconfig/libmfx.pc
    echo "Version: 1.26  ((MFX_VERSION) % 1000)"                                              >> ${LIBMFX_PC} && \
    echo ""                                                                                   >> ${LIBMFX_PC} && \
    echo "Libs: -L${INTEL_MEDIA_SDK_PATH}/lib/lin_x64 -lmfx -ldl -lstdc++ -lrt -lva -lva-drm" >> ${LIBMFX_PC} && \
    echo "Libs.private: -lstdc++ -ldl"                                                        >> ${LIBMFX_PC} && \
    echo "Cflags: -I${INTEL_MEDIA_SDK_PATH}/include"                                          >> ${LIBMFX_PC}
    # rm /usr/lib64/libdrm* /usr/lib64/libva* TODO: Should we do this?

################
# Build ffmpeg #
################
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -sL https://github.com/Intel-FFmpeg-Plugin/Intel_FFmpeg_plugins/archive/${QSV_FFMPEG_VERSION}.tar.gz | \
    tar -zx --strip-components=1 && \
    ./configure --prefix=${PREFIX} \
                # optimize for size rather than speed
                --enable-small \
                --disable-doc \
                --disable-debug \
                # HWaccel codecs
                --enable-libmfx \
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
