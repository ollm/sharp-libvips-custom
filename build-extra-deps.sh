#!/usr/bin/env bash
set -e

STEP="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Versions
if [ -f /packaging/versions.properties ]; then
  source /packaging/versions.properties
elif [ -f "${SCRIPT_DIR}/versions.properties" ]; then
  source "${SCRIPT_DIR}/versions.properties"
fi

# Paths
case ${PLATFORM} in
  linux*)
    DEPS=/deps
    TARGET=/target
    PACKAGE=/packaging
    ROOT=/root
    ;;
  darwin*)
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    DEPS=${PROJECT_ROOT}/deps
    TARGET=${PROJECT_ROOT}/target
    PACKAGE=${PROJECT_ROOT}
    ROOT=${PROJECT_ROOT}/platforms/$PLATFORM
    ;;
esac

CURL="curl --silent --location --retry 3 --retry-max-time 30 --fail"

# pre-heif
if [ "$STEP" = "pre-heif" ] || [ "$STEP" = "all" ]; then

  # dav1d (AV1 decoder required by libheif for AVIF/HEIC decoding)
  mkdir ${DEPS}/dav1d
  $CURL https://github.com/videolan/dav1d/archive/${VERSION_DAV1D}.tar.gz | tar xzC ${DEPS}/dav1d --strip-components=1
  cd ${DEPS}/dav1d
  meson setup _build --default-library=static --buildtype=release --strip --prefix=${TARGET} ${MESON} \
    -Denable_tools=false \
    -Denable_tests=false
  meson install -C _build --tag devel

  # libde265 (HEVC/H.265 decoder required by libheif for HEIC decoding)
  mkdir ${DEPS}/de265
  $CURL https://github.com/strukturag/libde265/releases/download/v${VERSION_DE265}/libde265-${VERSION_DE265}.tar.gz | tar xzC ${DEPS}/de265 --strip-components=1
  cd ${DEPS}/de265
  cmake -G"Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE=${ROOT}/Toolchain.cmake -DCMAKE_INSTALL_PREFIX=${TARGET} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DBUILD_SHARED_LIBS=FALSE \
    -DENABLE_DECODER=OFF \
    -DENABLE_ENCODER=OFF \
    -DENABLE_SDL=OFF \
    .
  make install/strip
fi

# pre-vips
if [ "$STEP" = "pre-vips" ] || [ "$STEP" = "all" ]; then

  # brotli (required by libjxl)
  mkdir ${DEPS}/brotli
  $CURL https://github.com/google/brotli/archive/v${VERSION_BROTLI}.tar.gz | tar xzC ${DEPS}/brotli --strip-components=1
  cd ${DEPS}/brotli
  cmake -G"Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE=${ROOT}/Toolchain.cmake -DCMAKE_INSTALL_PREFIX=${TARGET} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DBUILD_SHARED_LIBS=FALSE \
    -DBROTLI_DISABLE_TESTS=ON \
    .
  make install/strip

  # openjpeg (JPEG 2000 / JP2 support)
  mkdir ${DEPS}/openjpeg
  $CURL https://github.com/uclouvain/openjpeg/archive/v${VERSION_OPENJPEG}.tar.gz | tar xzC ${DEPS}/openjpeg --strip-components=1
  cd ${DEPS}/openjpeg
  cmake -G"Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE=${ROOT}/Toolchain.cmake -DCMAKE_INSTALL_PREFIX=${TARGET} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DBUILD_SHARED_LIBS=FALSE \
    -DBUILD_TESTING=OFF \
    -DBUILD_CODEC=OFF \
    .
  make install/strip

  # libjxl (JPEG XL support)
  if [ -z "$WITHOUT_HIGHWAY" ]; then
    mkdir ${DEPS}/jxl
    $CURL https://github.com/libjxl/libjxl/archive/v${VERSION_JXL}.tar.gz | tar xzC ${DEPS}/jxl --strip-components=1
    cd ${DEPS}/jxl
    CFLAGS="${CFLAGS} -O3" CXXFLAGS="${CXXFLAGS} -O3" cmake -G"Unix Makefiles" \
      -DCMAKE_TOOLCHAIN_FILE=${ROOT}/Toolchain.cmake -DCMAKE_INSTALL_PREFIX=${TARGET} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DBUILD_SHARED_LIBS=FALSE \
      -DBUILD_TESTING=OFF \
      -DJPEGXL_ENABLE_TOOLS=OFF \
      -DJPEGXL_ENABLE_DOXYGEN=OFF \
      -DJPEGXL_ENABLE_MANPAGES=OFF \
      -DJPEGXL_ENABLE_BENCHMARK=OFF \
      -DJPEGXL_ENABLE_EXAMPLES=OFF \
      -DJPEGXL_ENABLE_SJPEG=OFF \
      -DJPEGXL_ENABLE_OPENEXR=OFF \
      -DJPEGXL_ENABLE_SKCMS=OFF \
      -DJPEGXL_ENABLE_TRANSCODE_JPEG=OFF \
      -DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
      -DJPEGXL_FORCE_SYSTEM_LCMS2=ON \
      -DJPEGXL_FORCE_SYSTEM_HWY=ON .
    make install/strip
  fi

  find ${TARGET}/lib/pkgconfig -name "*.pc" -exec sed -i 's/-l-lpthread/-lpthread/g' {} \;
fi