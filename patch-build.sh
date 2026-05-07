#!/usr/bin/env bash
set -e

PLATFORM=$1

# Include shared patch-common.sh for shared patching logic
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/patch-common.sh"

# Platform-specific patching
case ${PLATFORM} in
  win32*)
    # Windows
    BUILD_FILE="build/win.sh"

    # Exit early if already patched
    grep -q '\-web-' "$BUILD_FILE" || exit 0

    # Switch from 'web-*-static' to 'all' build variant which includes JXL, HEIC and JP2
    # Captures the version variable to preserve it: -web-${VERSION_VIPS}-static → -all-${VERSION_VIPS}
    sed -i.bak 's/-web-\(.*\)-static/-all-\1/' "$BUILD_FILE"
    sed -i.bak 's|lib/libvips.lib|lib/*.lib|' "$BUILD_FILE"
    rm -f "${BUILD_FILE}.bak"

    node ./patch-common.js "${BUILD_FILE}"

    # Validate
    grep -q '\-all-' "$BUILD_FILE" || exit 1
    ;;
  *)
    # Linux and macOS
    BUILD_FILE="build/posix.sh"

    # Exit early if already patched
    grep -q 'jpeg-xl=disabled' "$BUILD_FILE" || exit 0

    # Remplace curl retry flags
    sed -i.bak 's/--retry 3 --retry-max-time 30/--fail --show-error --retry 3 --retry-delay 2 --retry-max-time 60/g' "$BUILD_FILE"

    # Enable JXL
    sed -i.bak 's/-Djpeg-xl=disabled/-Djpeg-xl=$([ -z "${WITHOUT_HIGHWAY}" ] \&\& echo enabled || echo disabled)/' "$BUILD_FILE"

    # Enable openjpeg (JP2)
    sed -i.bak 's/-Dopenjpeg=disabled/-Dopenjpeg=enabled/' "$BUILD_FILE"

    # Enable libde265 HEVC decoder
    #sed -i.bak 's/-DWITH_LIBDE265=0/-DWITH_LIBDE265=1/' "$BUILD_FILE"

    # Enable DAV1D AV1 decoder
    sed -i.bak 's/-DWITH_X265=0/-DWITH_X265=0 -DWITH_DAV1D=1/' "$BUILD_FILE"

    # Enable high bit depth
    sed -i.bak 's/-DCONFIG_AV1_HIGHBITDEPTH=0/-DCONFIG_AV1_HIGHBITDEPTH=1/' "$BUILD_FILE"

    # Inject dav1d + libde265 build steps before heif build
    awk '
    /mkdir \$\{DEPS\}\/heif/ {
      print "bash ${PACKAGE}/custom/build-extra-deps.sh pre-heif"
    }
    { print }
    ' "$BUILD_FILE" > /tmp/posix.sh.tmp && mv /tmp/posix.sh.tmp "$BUILD_FILE"

    # Inject brotli + openjpeg + libjxl build steps before vips build
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