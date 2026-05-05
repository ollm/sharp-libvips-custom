#!/usr/bin/env bash
set -e

## Copyright 2017 Lovell Fuller and others.
## SPDX-License-Identifier: Apache-2.0

# Dependency version numbers
source ./versions.properties

# Common options for curl
CURL="curl --silent --location --retry 3 --retry-max-time 30"

# Check for newer versions
ALL_AT_VERSION_LATEST=true
UPDATES=()
version_latest() {
  VERSION_SELECTOR="stable_versions"
  if [[ "$4" == *"unstable"* ]]; then
    VERSION_SELECTOR="versions"
  fi
  if [[ "$3" == *"/"* ]]; then
    VERSION_LATEST=$(git -c 'versionsort.suffix=-' ls-remote --tags --refs --sort='v:refname' https://github.com/$3.git | awk -F'/' 'END{print $3}' | tr -d 'v')
  else
    VERSION_LATEST=$($CURL "https://release-monitoring.org/api/v2/versions/?project_id=$3" | jq -j ".$VERSION_SELECTOR[0]" | tr '_' '.')
  fi
  if [ "$VERSION_LATEST" != "" ] && [ "$VERSION_LATEST" != "$2" ]; then
    ALL_AT_VERSION_LATEST=false
    VERSION_VAR=$(echo "VERSION_$1" | tr [:lower:]- [:upper:]_)
    sed -i "s/^$VERSION_VAR=.*/$VERSION_VAR=$VERSION_LATEST/" versions.properties
    UPDATES+=("$1")
  fi
  sleep 1
}

version_latest "brotli" "$VERSION_BROTLI" "google/brotli"
version_latest "dav1d" "$VERSION_DAV1D" "videolan/dav1d"
version_latest "de265" "$VERSION_DE265" "strukturag/libde265"
version_latest "jxl" "$VERSION_JXL" "libjxl/libjxl"
version_latest "openjpeg" "$VERSION_OPENJPEG" "uclouvain/openjpeg"

if [ "$ALL_AT_VERSION_LATEST" = "false" ]; then
  echo "Dependency updates: ${UPDATES[*]}"
fi
