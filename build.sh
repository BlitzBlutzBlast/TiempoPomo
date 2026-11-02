#!/usr/bin/env bash
# Builds PomTiempo.app and a DMG into dist/.
#
#   ./build.sh            # version 0.1.0, this Mac's architecture
#   ./build.sh 0.2.0      # a given version
#   UNIVERSAL=1 ./build.sh 0.2.0   # Apple silicon + Intel (needs Xcode)
#
# The app is ad-hoc signed, not notarized: the first time it's opened, macOS
# asks you to confirm (right-click → Open, or Privacy & Security → Open Anyway).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-0.1.0}"
BUILD="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
APP_NAME="PomTiempo"
DIST="dist"
APP="$DIST/$APP_NAME.app"

ARGS=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARGS+=(--arch arm64 --arch x86_64)
fi

# Command Line Tools without Xcode ship SDKs whose SwiftUI needs a macro
# plugin they don't include; fall back to the newest SDK that builds.
if ! xcode-select -p | grep -q "Xcode" && [[ -z "${SDKROOT:-}" ]]; then
  for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15*.sdk; do
    if [[ -d "$sdk" ]]; then export SDKROOT="$sdk"; break; fi
  done
fi

scripts/check_no_network.sh

echo "==> Compiling $APP_NAME $VERSION ($BUILD)"
swift build "${ARGS[@]}"
BIN_DIR="$(swift build "${ARGS[@]}" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc, sandboxed, no network)"
codesign --force --options runtime --entitlements Resources/PomTiempo.entitlements --sign - "$APP"
scripts/check_no_network.sh "$APP"

echo "==> Packaging DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# A double-click installer that puts the app straight into /Applications.
echo "==> Packaging installer"
PKGROOT="$(mktemp -d)"
cp -R "$APP" "$PKGROOT/"
COMPONENTS="$(mktemp -d)/components.plist"
pkgbuild --analyze --root "$PKGROOT" "$COMPONENTS" >/dev/null
# Always install to /Applications, never into a copy found elsewhere on disk.
plutil -replace 0.BundleIsRelocatable -bool NO "$COMPONENTS"
PKG="$DIST/$APP_NAME-$VERSION.pkg"
pkgbuild --root "$PKGROOT" --component-plist "$COMPONENTS" \
  --install-location /Applications \
  --identifier com.blitzblutzblast.pomtiempo.pkg --version "$VERSION" \
  "$PKG" >/dev/null
rm -rf "$PKGROOT"

echo "==> Done: $DMG"
echo "==> Done: $PKG"
