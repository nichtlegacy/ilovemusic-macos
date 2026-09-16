#!/usr/bin/env bash
# Packages an already-built .build/ILoveMusic.app into a distributable DMG.
# Output: dist/ILoveMusic-<version>.dmg
#
# Run Scripts/build-app.sh first, or use Scripts/release.sh which does both.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="ILoveMusic"
APP_DIR=".build/${NAME}.app"
DIST_DIR="dist"

if [ ! -d "$APP_DIR" ]; then
  echo "error: ${APP_DIR} not found, run Scripts/build-app.sh first" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_DIR}/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP_DIR}/Contents/Info.plist")"
DMG_PATH="${DIST_DIR}/${NAME}-${VERSION}.dmg"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "==> Staging ${NAME} ${VERSION} (build ${BUILD_NUMBER})"
cp -R "$APP_DIR" "$STAGING/${NAME}.app"
ln -s /Applications "$STAGING/Applications"

# The staged copy must not carry quarantine or extended attributes into the image.
xattr -cr "$STAGING/${NAME}.app"

echo "==> Creating ${DMG_PATH}"
hdiutil create \
  -volname "${NAME} ${VERSION}" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  -quiet \
  "$DMG_PATH"

echo
echo "Built: ${DMG_PATH}"
echo "Size:  $(du -h "$DMG_PATH" | cut -f1)"
