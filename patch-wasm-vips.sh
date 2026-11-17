#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WASM_VIPS_DIR="${1:?Usage: patch-wasm-vips.sh WASM_VIPS_DIR}"
BUILD_FILE="${WASM_VIPS_DIR}/build.sh"

if [ ! -f "$BUILD_FILE" ]; then
  echo "WASM-vips build script not found: $BUILD_FILE" >&2
  exit 1
fi

source "${SCRIPT_DIR}/versions.properties"

# Exit early if already patched
grep -q '# CUSTOM - OPENJPEG START' "$BUILD_FILE" && exit 0

# Add OpenJPEG version
sed -i.bak "/^VERSION_EMSCRIPTEN=/i\\
VERSION_OPENJPEG=${VERSION_OPENJPEG} # custom JP2 support
" "$BUILD_FILE"

# Build OpenJPEG before libvips
sed -i.bak '/vips\.pc.*|| (/i\
# CUSTOM - OPENJPEG START\
[ -f "$TARGET/lib/pkgconfig/libopenjp2.pc" ] || (\
  stage "Compiling openjpeg"\
  mkdir $DEPS/openjpeg\
  curl -fLs https://github.com/uclouvain/openjpeg/archive/refs/tags/v${VERSION_OPENJPEG}.tar.gz | tar xzC $DEPS/openjpeg --strip-components=1\
  cd $DEPS/openjpeg\
  emcmake cmake -B_build -S. -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=$TARGET -DCMAKE_FIND_ROOT_PATH=$TARGET -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_CODEC=OFF\
  make -C _build install\
)\
# CUSTOM - OPENJPEG END
' "$BUILD_FILE"

# Include OpenJPEG in the version metadata
awk '/printf.*VERSION_PNG/ { print "  printf \"  \\\"openjpeg\\\": \\\"${VERSION_OPENJPEG}\\\",\\n\"; \\" } { print }' \
  "$BUILD_FILE" > /tmp/wasm-vips-build.sh.tmp &&
  mv /tmp/wasm-vips-build.sh.tmp "$BUILD_FILE"

# Enable JXL and JP2
sed -i.bak 's|\${DISABLE_JXL:+-Djpeg-xl=disabled}|${DISABLE_JXL:+-Djpeg-xl=disabled} ${ENABLE_JXL:+-Djpeg-xl=enabled}|' "$BUILD_FILE"
sed -i.bak 's/-Dopenjpeg=disabled/-Dopenjpeg=enabled/' "$BUILD_FILE"

rm -f "${BUILD_FILE}.bak"
chmod +x "$BUILD_FILE"

# Validate
grep -Fq '# CUSTOM - OPENJPEG START' "$BUILD_FILE"
grep -Fq '${ENABLE_JXL:+-Djpeg-xl=enabled}' "$BUILD_FILE"
grep -Fq -- '-Dopenjpeg=enabled' "$BUILD_FILE"
grep -Fq 'VERSION_OPENJPEG}' "$BUILD_FILE"
