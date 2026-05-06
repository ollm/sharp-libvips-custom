#!/usr/bin/env bash
set -e

# Append custom version numbers to the upstream versions.properties
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat "${SCRIPT_DIR}/versions.properties" >> ./versions.properties

# Appen THIRD-PARTY-NOTICES.md with custom licenses
awk -v file="${SCRIPT_DIR}/THIRD-PARTY-NOTICES.md" '
/^\|/ { last = NR }
{ lines[NR] = $0 }
END {
  for (i = 1; i <= NR; i++) {
    print lines[i]
    if (i == last) {
      while ((getline line < file) > 0) print line
      close(file)
    }
  }
}
' THIRD-PARTY-NOTICES.md > tmp && mv tmp THIRD-PARTY-NOTICES.md

# Replace @img/sharp with @img-custom/sharp in .json and .js only
find . \
  \( -path './.git' -o -path '*/.git/*' \) -prune -o \
  -type f \( -name '*.json' -o -name '*.js' -o -name '*.cjs' -o -name '*.mjs' \) \
  ! -name '*.bak' \
  -exec sed -i.bak 's|@img/sharp-|@img-custom/sharp-|g' {} +

# Replace lovell/sharp-libvips with ollm/sharp-libvips-custom in .json (For provenance)
find . \
  \( -path './.git' -o -path '*/.git/*' \) -prune -o \
  -type f -name '*.json' \
  ! -name '*.bak' \
  -exec sed -i.bak 's|lovell/sharp-libvips|ollm/sharp-libvips-custom|g' {} +

# Replace version (Only for developing): sharp-libvips
find . \
  \( -path './.git' -o -path '*/.git/*' \) -prune -o \
  -type f -name '*.json' \
  ! -name '*.bak' \
  -exec sed -i.bak 's|"1.3.0-rc.[0-9]+"|"1.3.0-rc.6-2"|g' {} +