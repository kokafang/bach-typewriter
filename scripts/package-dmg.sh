#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
APP="$ROOT/Preview/BachTypewriter.app"
RESOURCES="$APP/Contents/Resources"
BUNDLE_NAME="bach-typewriter-swift_bach-typewriter-swift.bundle"
PACKAGES="$ROOT/Packages"
STAGING="$PACKAGES/dmg-staging"
DMG="$PACKAGES/BachTypewriter-arm64.dmg"
ZIP="$PACKAGES/BachTypewriter-preview-arm64.zip"

cd "$ROOT"
swift build -c release

cp "$BUILD_DIR/bach-typewriter-swift" "$APP/Contents/MacOS/BachTypewriter"
cp "$BUILD_DIR/BachAudioHelper" "$APP/Contents/MacOS/BachAudioHelper"

rm -rf "$RESOURCES/$BUNDLE_NAME"
cp -R "$BUILD_DIR/$BUNDLE_NAME" "$RESOURCES/"

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Bach Typewriter" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
rm -rf "$STAGING"

shasum -a 256 "$DMG" "$ZIP"
