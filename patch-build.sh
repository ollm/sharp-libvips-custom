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
    HASH="17ad2f6"

    # Exit early if already patched
    grep -q 'ollm/build-win64-mxe-custom' "$BUILD_FILE" && exit 0

    # Switch from 'libvips/build-win64-mxe' to 'ollm/build-win64-mxe-custom'
    sed -i.bak 's|libvips/build-win64-mxe|ollm/build-win64-mxe-custom|' "$BUILD_FILE"
    sed -i.bak "s|\${VERSION_VIPS}|${HASH}|g" "$BUILD_FILE"
    sed -i.bak "s|\${VERSION_VIPS_SHORT}|${HASH}|g" "$BUILD_FILE"

    # Temporarily, v${VERSION_VIPS} to v${VERSION_VIPS}-4
    sed -i.bak 's|v${VERSION_VIPS}|v${VERSION_VIPS}-4|g' "$BUILD_FILE"
    sed -i.bak "s|v${HASH}|v\${VERSION_VIPS}-4|" "$BUILD_FILE"

    rm -f "${BUILD_FILE}.bak"

    # Validate
    grep -q 'ollm/build-win64-mxe-custom' "$BUILD_FILE" || exit 1
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