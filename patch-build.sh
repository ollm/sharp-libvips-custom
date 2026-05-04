#!/usr/bin/env bash
set -e

PLATFORM=$1

# Include shared patch-common.sh for shared patching logic
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/patch-common.sh"

# Platform-specific patching
case ${PLATFORM} in
  win32*)
    BUILD_FILE="build/win.sh"

    # Exit early if already patched (already using 'all' build)
    grep -q '\-web-' "$BUILD_FILE" || exit 0

    # Switch from 'web-*-static' to 'all' build variant which includes JXL and HEIC
    # Captures the version variable to preserve it: -web-${VERSION_VIPS}-static → -all-${VERSION_VIPS}
    sed -i.bak 's/-web-\(.*\)-static/-all-\1/' "$BUILD_FILE"
    sed -i.bak 's|lib/libvips.lib|lib/*.lib|' "$BUILD_FILE"
    rm -f "${BUILD_FILE}.bak"

    # Validate
    grep -q '\-all-' "$BUILD_FILE" || exit 1
    ;;
  *)
    # Linux and macOS: patch posix.sh
    BUILD_FILE="build/posix.sh"

    # Exit early if already patched
    grep -q 'jpeg-xl=disabled' "$BUILD_FILE" || exit 0

    # Enable JXL in vips meson build on platforms that have highway;
    # on platforms where WITHOUT_HIGHWAY is set, keep JXL disabled at runtime.
    sed -i.bak 's/-Djpeg-xl=disabled/-Djpeg-xl=$([ -z "${WITHOUT_HIGHWAY}" ] \&\& echo enabled || echo disabled)/' "$BUILD_FILE"

    # Enable openjpeg (JP2) in vips meson build
    sed -i.bak 's/-Dopenjpeg=disabled/-Dopenjpeg=enabled/' "$BUILD_FILE"

    # Enable DAV1D decoder in libheif cmake build (for HEIC AV1 support)
    sed -i.bak 's/-DWITH_X265=0/-DWITH_X265=0 -DWITH_DAV1D=1/' "$BUILD_FILE"

    # Enable high bit depth in dav1d
    sed -i.bak 's/-DCONFIG_AV1_HIGHBITDEPTH=0/-DCONFIG_AV1_HIGHBITDEPTH=1/' "$BUILD_FILE"

    # Inject dav1d build BEFORE heif (dav1d is required by libheif for HEIC/AV1)
    # NOTE: ${PACKAGE} is written literally here; posix.sh expands it at runtime
    awk '
    /mkdir \$\{DEPS\}\/heif/ {
      print "bash ${PACKAGE}/custom/build-extra-deps.sh pre-heif"
    }
    { print }
    ' "$BUILD_FILE" > /tmp/posix.sh.tmp && mv /tmp/posix.sh.tmp "$BUILD_FILE"

    # Inject brotli + openjpeg + libjxl build BEFORE vips
    # (highway, lcms2, and libpng are all built by posix.sh before this point)
    # NOTE: ${PACKAGE} is written literally here; posix.sh expands it at runtime
    awk '
    /mkdir \$\{DEPS\}\/vips/ {
      print "bash ${PACKAGE}/custom/build-extra-deps.sh pre-vips"
    }
    { print }
    ' "$BUILD_FILE" > /tmp/posix.sh.tmp && mv /tmp/posix.sh.tmp "$BUILD_FILE"

    chmod +x "$BUILD_FILE"
    rm -f "${BUILD_FILE}.bak"

    # Validate
    grep -q 'jpeg-xl=\$(' "$BUILD_FILE" || exit 1
    grep -q 'openjpeg=enabled' "$BUILD_FILE" || exit 1
    ;;
esac