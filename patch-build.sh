#!/usr/bin/env bash
set -e

PLATFORM=$1

# Exit if it has already been applied 
grep -q "jpeg-xl=enabled" $BUILD_FILE || exit 0
grep -q "openjpeg=enabled" $BUILD_FILE || exit 0

# Linux
BUILD_FILE="build/posix.sh"

# JXL and JX2
sed -i 's/-Djpeg-xl=disabled/-Djpeg-xl=enabled/' $BUILD_FILE
sed -i 's/-Dopenjpeg=disabled/-Dopenjpeg=enabled/' $BUILD_FILE

# HEIF
sed -i 's/-DWITH_X265=0/-DWITH_X265=0 -DWITH_DAV1D=1/' $BUILD_FILE

# Inject extra build
awk '
/mkdir \$\{DEPS\}\/vips/ {
  print "bash ./build-extra-deps.sh"
}
{ print }
' $BUILD_FILE > tmp && mv tmp $BUILD_FILE

chmod +x $BUILD_FILE

# Inject versions
cat ./versions.properties >> ../versions.properties

# Validate
grep -q "jpeg-xl=enabled" $BUILD_FILE || exit 1
grep -q "openjpeg=enabled" $BUILD_FILE || exit 1