#!/bin/bash
# Bump the columbia formula to a new release tag: ./bump.sh v1.4.4
# Downloads the tag's tarball, rewrites url+sha256 in the formula, and commits.
set -euo pipefail
TAG="${1:?usage: ./bump.sh vX.Y.Z}"
URL="https://github.com/wbsmolen/columbia/archive/refs/tags/${TAG}.tar.gz"
TMP=$(mktemp)
curl -fsSL "$URL" -o "$TMP"
SHA=$(shasum -a 256 "$TMP" | awk '{print $1}')
rm -f "$TMP"
F="$(dirname "$0")/Formula/columbia.rb"
sed -i '' -E "s|archive/refs/tags/v[0-9.]+\.tar\.gz|archive/refs/tags/${TAG}.tar.gz|" "$F"
sed -i '' -E "s|sha256 \"[0-9a-f]{64}\"|sha256 \"${SHA}\"|" "$F"
git -C "$(dirname "$0")" add Formula/columbia.rb
git -C "$(dirname "$0")" commit -m "columbia ${TAG}"
echo "Bumped to ${TAG} (${SHA}). Review then: git push"
