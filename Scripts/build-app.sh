#!/usr/bin/env bash
# Builds ILoveMusic as a standalone .app bundle (Apple Silicon only).
# Output: .build/ILoveMusic.app
# Install: mv .build/ILoveMusic.app /Applications/
#
# Versioning:
#   VERSION      marketing version, read from the repo's VERSION file, env-overridable
#   BUILD_NUMBER monotonic integer, defaults to the commit count, env-overridable
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="ILoveMusic"
DISPLAY_NAME="ILoveMusic"
BUNDLE_ID="com.nichtlegacy.${NAME}"
MIN_OS="14.0"
FEED_URL="https://raw.githubusercontent.com/nichtlegacy/ilovemusic_mac/main/appcast.xml"
SPARKLE_PUBLIC_KEY="AUirFpMVvlCOQcflFJ5exmSeZmJ/CwevT5+vkHvQs/8="

VERSION="${VERSION:-$(tr -d '[:space:]' < VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo "")}"
BUILD_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION must be X.Y.Z, got '${VERSION}'" >&2
  exit 1
fi
if ! [[ "${BUILD_NUMBER}" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: BUILD_NUMBER must be a positive integer, got '${BUILD_NUMBER}'" >&2
  echo "hint: outside a git checkout, pass BUILD_NUMBER=<n> explicitly" >&2
  exit 1
fi

# Sparkle decides whether an update is newer purely by CFBundleVersion. Since
# the build number is the commit count, anything that rewrites history restarts
# the count, and a build that looks older than what is already published would
# never be offered to anyone who installed the higher number. Refuse to build
# it rather than publish a dead end.
if [ -f appcast.xml ]; then
  PUBLISHED_BUILD="$(
    sed -n 's/.*<sparkle:version>\([0-9][0-9]*\)<\/sparkle:version>.*/\1/p' appcast.xml \
      | sort -n | tail -1
  )"
  if [ -n "${PUBLISHED_BUILD}" ] && [ "${BUILD_NUMBER}" -lt "${PUBLISHED_BUILD}" ]; then
    echo "error: BUILD_NUMBER ${BUILD_NUMBER} is below the published build ${PUBLISHED_BUILD}" >&2
    echo "hint: the commit count restarted, most likely after a history rewrite." >&2
    echo "      Pass BUILD_NUMBER=$((PUBLISHED_BUILD + 1)) or higher." >&2
    exit 1
  fi
fi

BUILD_DIR=".build/release"
APP_DIR=".build/${NAME}.app"
RESOURCE_BUNDLE="${NAME}_${NAME}.bundle"
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

echo "==> ${NAME} ${VERSION} (build ${BUILD_NUMBER})"

# 1. Build release binary
echo "==> Building release binary (arm64)"
mkdir -p .build/module-cache .build/swiftpm-cache
SWIFTPM_ENABLE_PLUGINS=0 \
SWIFTPM_CACHE_PATH="$PWD/.build/swiftpm-cache" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache" \
swift build -c release --disable-sandbox --arch arm64

# 2. Reset .app skeleton
echo "==> Assembling .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Helpers"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

cp "${BUILD_DIR}/${NAME}" "$APP_DIR/Contents/MacOS/${NAME}"
chmod +x "$APP_DIR/Contents/MacOS/${NAME}"
cp "${BUILD_DIR}/${NAME}Relauncher" "$APP_DIR/Contents/Helpers/${NAME}Relauncher"
chmod +x "$APP_DIR/Contents/Helpers/${NAME}Relauncher"

if [ -d "${BUILD_DIR}/${RESOURCE_BUNDLE}" ]; then
  cp -R "${BUILD_DIR}/${RESOURCE_BUNDLE}" "$APP_DIR/Contents/Resources/"
fi

# SwiftPM's command-line build currently copies String Catalog sources without
# compiling them. Compile the shipping catalog into the copied resource bundle
# so Foundation can discover the German `.lproj` at runtime.
STRING_CATALOG="Sources/ILoveMusic/Resources/Localizable.xcstrings"
if [ -f "$STRING_CATALOG" ]; then
  xcrun xcstringstool compile "$STRING_CATALOG" \
    --output-directory "$APP_DIR/Contents/Resources/${RESOURCE_BUNDLE}" \
    --language en \
    --language de
fi

if [ -f "Sources/ILoveMusic/Resources/AppIcon.icns" ]; then
  cp "Sources/ILoveMusic/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

# Sparkle ships as a dynamic framework; the executable resolves it through the
# @executable_path/../Frameworks rpath set in Package.swift.
if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
  echo "error: Sparkle framework missing at ${SPARKLE_FRAMEWORK}" >&2
  echo "hint: run 'swift package resolve' first" >&2
  exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/"

# 3. Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${NAME}</string>
  <key>CFBundleDisplayName</key><string>${DISPLAY_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleExecutable</key><string>${NAME}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleSignature</key><string>????</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>de</string>
  </array>
  <key>LSMinimumSystemVersion</key><string>${MIN_OS}</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>ILoveMusicBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
  <key>SUFeedURL</key><string>${FEED_URL}</string>
  <key>SUPublicEDKey</key><string>${SPARKLE_PUBLIC_KEY}</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>NSHumanReadableCopyright</key><string>ILoveMusic — public-data macOS menu bar player</string>
</dict>
</plist>
EOF

# 4. Ad-hoc signing, inside out.
# Without an Apple Developer account there is no Developer ID identity and no
# notarization, so first launch of a downloaded build always hits Gatekeeper.
# Sparkle verifies updates by EdDSA signature, which does not depend on Apple.
echo "==> Ad-hoc signing (not notarized; first launch of a download needs a Gatekeeper override)"
SPARKLE_IN_APP="$APP_DIR/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - --timestamp=none "$SPARKLE_IN_APP/Versions/B/XPCServices/Downloader.xpc"
codesign --force --sign - --timestamp=none "$SPARKLE_IN_APP/Versions/B/XPCServices/Installer.xpc"
codesign --force --sign - --timestamp=none "$SPARKLE_IN_APP/Versions/B/Updater.app"
codesign --force --sign - --timestamp=none "$SPARKLE_IN_APP/Versions/B/Autoupdate"
codesign --force --sign - --timestamp=none "$SPARKLE_IN_APP"
codesign --force --sign - --timestamp=none "$APP_DIR/Contents/Helpers/${NAME}Relauncher"
codesign --force --sign - --timestamp=none "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo
echo "Built: $APP_DIR  (${VERSION} build ${BUILD_NUMBER})"
echo
echo "Install:"
echo "  mv \"$APP_DIR\" /Applications/"
echo "  xattr -dr com.apple.quarantine /Applications/${NAME}.app   # only needed for downloaded builds"
echo "  open /Applications/${NAME}.app"
