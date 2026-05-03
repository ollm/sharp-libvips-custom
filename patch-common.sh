#!/usr/bin/env bash
set -e

# Append custom version numbers to the upstream versions.properties
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat "${SCRIPT_DIR}/versions.properties" >> ./versions.properties

# Replace @img/sharp with @img-custom/sharp in .json and .js only
find . \
  \( -path './.git' -o -path '*/.git/*' \) -prune -o \
  -type f \( -name '*.json' -o -name '*.js' \) \
  ! -name '*.bak' \
  -exec sed -i.bak 's|@img/sharp-|@img-custom/sharp-|g' {} +

# Replace lovell/sharp-libvips with ollm/sharp-libvips-custom in .json (For provenance)
find . \
  \( -path './.git' -o -path '*/.git/*' \) -prune -o \
  -type f -name '*.json' \
  ! -name '*.bak' \
  -exec sed -i.bak 's|lovell/sharp-libvips|ollm/sharp-libvips-custom|g' {} +

# Replace version (Only for developing)
find . \
  \( -path './.git' -o -path '*/.git/*' \) -prune -o \
  -type f -name '*.json' \
  ! -name '*.bak' \
  -exec sed -i.bak 's|"1.3.0-rc.6"|"0.0.8"|g' {} +