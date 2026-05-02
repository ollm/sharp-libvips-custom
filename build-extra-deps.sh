#!/usr/bin/env bash
set -e

# Step to execute: 'pre-heif' builds dav1d, 'pre-vips' builds brotli+openjpeg+libjxl
STEP="${1:-all}"

# Resolve the workspace root from the script's location, regardless of the
# caller's working directory (posix.sh cds into build subdirectories before
# calling this script, making $PWD unreliable).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Dependency version numbers
if [ -f /packaging/versions.properties ]; then
  source /packaging/versions.properties
elif [ -f "${WORKSPACE_ROOT}/versions.properties" ]; then
  source "${WORKSPACE_ROOT}/versions.properties"
fi

# Environment / working directories (mirrors posix.sh)
case ${PLATFORM} in
  linux*)
    DEPS=/deps
    TARGET=/target
    PACKAGE=/packaging
    ROOT=/root
    ;;
  darwin*)
    DEPS=$WORKSPACE_ROOT/deps
    TARGET=$WORKSPACE_ROOT/target
    PACKAGE=$WORKSPACE_ROOT
    ROOT=$WORKSPACE_ROOT/platforms/$PLATFORM
    ;;
esac

CURL="curl --silent --location --retry 3 --retry-max-time 30 --fail"

# -----------------------------
# pre-heif: dav1d
# AV1 decoder required by libheif for HEIC decoding
# -----------------------------
if [ "$STEP" = "pre-heif" ] || [ "$STEP" = "all" ]; then
  mkdir "${DEPS}/dav1d"
  $CURL https://github.com/videolan/dav1d/archive/${VERSION_DAV1D}.tar.gz | tar xzC "${DEPS}/dav1d" --strip-components=1
  cd "${DEPS}/dav1d"
  meson setup _build --default-library=static --buildtype=release --strip --prefix=${TARGET} ${MESON} \
    -Denable_tools=false \
    -Denable_tests=false
  meson install -C _build --tag devel
fi

# -----------------------------
# pre-vips: brotli, openjpeg, libjxl
# All built after highway, lcms2, and libpng are already installed by posix.sh
# -----------------------------
if [ "$STEP" = "pre-vips" ] || [ "$STEP" = "all" ]; then

  # brotli (required by libjxl)
  mkdir "${DEPS}/brotli"
  $CURL https://github.com/google/brotli/archive/v${VERSION_BROTLI}.tar.gz | tar xzC "${DEPS}/brotli" --strip-components=1
  cd "${DEPS}/brotli"
  cmake -G"Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE=${ROOT}/Toolchain.cmake -DCMAKE_INSTALL_PREFIX=${TARGET} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DBUILD_SHARED_LIBS=FALSE \
    -DBROTLI_DISABLE_TESTS=ON \
    .
  make install/strip

  # openjpeg (JPEG 2000 / JP2 support)
  mkdir "${DEPS}/openjpeg"
  $CURL https://github.com/uclouvain/openjpeg/archive/v${VERSION_OPENJPEG}.tar.gz | tar xzC "${DEPS}/openjpeg" --strip-components=1
  cd "${DEPS}/openjpeg"
  cmake -G"Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE=${ROOT}/Toolchain.cmake -DCMAKE_INSTALL_PREFIX=${TARGET} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DBUILD_SHARED_LIBS=FALSE \
    -DBUILD_TESTING=OFF \
    -DBUILD_CODEC=OFF \
    .
  make install/strip

  # libjxl (JPEG XL support)
  # Depends on: highway (system), lcms2 (system), libpng (system), brotli (system - built above)
  mkdir "${DEPS}/jxl"
  $CURL https://github.com/libjxl/libjxl/archive/v${VERSION_JXL}.tar.gz | tar xzC "${DEPS}/jxl" --strip-components=1
  cd "${DEPS}/jxl"
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
    -DJPEGXL_FORCE_SYSTEM_HWY=ON \
    .
  make install/strip

fi
