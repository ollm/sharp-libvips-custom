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
    HASH="24ad4d0"

    # Exit early if already patched
    grep -q 'ollm/build-win64-mxe-custom' "$BUILD_FILE" && exit 0

    # Switch from 'libvips/build-win64-mxe' to 'ollm/build-win64-mxe-custom'
    sed -i.bak 's|libvips/build-win64-mxe|ollm/build-win64-mxe-custom|' "$BUILD_FILE"
    sed -i.bak "s|\${VERSION_VIPS}|${HASH}|g" "$BUILD_FILE"
    sed -i.bak "s|\${VERSION_VIPS_SHORT}|${HASH}|g" "$BUILD_FILE"

    # Temporarily, v${VERSION_VIPS} to v${VERSION_VIPS}-4
    # sed -i.bak 's|v${VERSION_VIPS}|v${VERSION_VIPS}-4|g' "$BUILD_FILE"

    # Change hash to version
    sed -i.bak "s|v${HASH}|v\${VERSION_VIPS}|" "$BUILD_FILE"

    rm -f "${BUILD_FILE}.bak"

    # Validate
    grep -q 'ollm/build-win64-mxe-custom' "$BUILD_FILE" || exit 1
    ;;
  dev-wasm32)
    BUILD_FILE="build/wasm.sh"

    # Exit early if already patched
    grep -q 'patch-wasm-vips.sh' "$BUILD_FILE" && exit 0

    # Enable JXL
    sed -i.bak 's/ --disable-jxl//' "$BUILD_FILE"

    # Patch downloaded wasm-vips
    sed -i.bak '/# Check libvips versions match/i\
bash ../custom/patch-wasm-vips.sh "$DIR"
' "$BUILD_FILE"

    rm -f "${BUILD_FILE}.bak"

    # Validate
    grep -q 'bash ../custom/patch-wasm-vips.sh "$DIR"' "$BUILD_FILE" || exit 1
    ! grep -q -- '--disable-jxl' "$BUILD_FILE" || exit 1
    grep -q -- '--enable-libvips-cpp' "$BUILD_FILE" || exit 1
    ;;
  *)
    # Linux and macOS
    BUILD_FILE="build/posix.sh"

    if [[ ${PLATFORM} == linux-* ]] && ! grep -q 'sharp-custom: build against GLib 2.72' "$BUILD_FILE"; then
      awk '
      {
        print
        if ($0 == "    LINUX=true") {
          print "    # sharp-custom: build against GLib 2.72"
          print "    VERSION_GLIB=2.72.0"
        }
      }
      ' "$BUILD_FILE" > /tmp/posix.sh.tmp && mv /tmp/posix.sh.tmp "$BUILD_FILE"
      sed -i.bak 's/-Dintrospection=disabled //' "$BUILD_FILE"
      rm -f "${BUILD_FILE}.bak"
    fi

    if [[ ${PLATFORM} == linux-* ]] && ! grep -q 'sharp-custom: use GLib 2.72-compatible GRegex patch' "$BUILD_FILE"; then
      grep -q 'glib-without-gregex.patch' "$BUILD_FILE" || {
        echo "Expected upstream GRegex patch command not found in $BUILD_FILE" >&2
        exit 1
      }
      awk '
      /glib-without-gregex\.patch/ {
        print "  # sharp-custom: use GLib 2.72-compatible GRegex patch"
        print "  patch -p1 < ${PACKAGE}/custom/glib-2.72-no-regex.patch"
        next
      }
      { print }
      ' "$BUILD_FILE" > /tmp/posix.sh.tmp && mv /tmp/posix.sh.tmp "$BUILD_FILE"
      grep -q 'sharp-custom: use GLib 2.72-compatible GRegex patch' "$BUILD_FILE" || exit 1
    fi

    if [[ ${PLATFORM} == linux-* ]] && ! grep -q 'sharp-custom: use system GLib at runtime' "$BUILD_FILE"; then
      # Build GLib shared so libvips can use the host's GLib at runtime.
      sed -i.bak \
        -e '/mkdir \${DEPS}\/glib/,/mkdir \${DEPS}\/xml2/s/--default-library=static/--default-library=shared/' \
        -e '/mkdir \${DEPS}\/glib/,/mkdir \${DEPS}\/xml2/s/--tag bin-devel,devel/--tag bin-devel,devel,runtime/' \
        "$BUILD_FILE"
      rm -f "${BUILD_FILE}.bak"

      # Keep the generated GLib libraries out of the Linux package.
      awk '
      {
        print
        if (index($0, "base_dep=$(basename $dep)") > 0) {
          print "    # sharp-custom: use system GLib at runtime"
          print "    if [ \"$LINUX\" = true ]; then"
          print "      case \"$base_dep\" in"
          print "        libglib-2.0.so*|libgobject-2.0.so*|libgmodule-2.0.so*|libgio-2.0.so*|libgthread-2.0.so*) continue ;;"
          print "      esac"
          print "    fi"
        }
      }
      ' "$BUILD_FILE" > /tmp/posix.sh.tmp && mv /tmp/posix.sh.tmp "$BUILD_FILE"
    fi

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

    # Enable high bit depth (Technically no longer necessary since https://github.com/lovell/sharp-libvips/pull/367)
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