#!/bin/sh
# Sets the mod version, commits it and tags the commit. Push both afterwards:
#   ./bump.sh 0.2.0
#   git push && git push --tags
set -e
Version="$1"
case "$Version" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "usage: $0 MAJOR.MINOR.PATCH"; exit 1 ;;
esac
cd "$(dirname "$0")"
printf 'return "%s"\n' "$Version" > Mods/ZF-Laser/Scripts/version.lua
git add Mods/ZF-Laser/Scripts/version.lua
git commit -m "v$Version"
git tag "v$Version"
echo "tagged v$Version"
