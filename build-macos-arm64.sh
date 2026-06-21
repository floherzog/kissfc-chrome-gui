#!/bin/sh
set -e

### KISS GUI — native Apple Silicon (arm64) macOS build
###
### Why this exists:
###   The historical build (gulpfile.js / nw-builder@3.x, and the separate
###   flyduino/kiss-gui wrapper) produces an Intel-only NW.js app. On Apple
###   Silicon + recent macOS it runs under Rosetta 2 and crashes (SIGSEGV in
###   the old Chromium). This script builds a NATIVE arm64 bundle instead.
###
### Approach (no nw-builder / gulp — the app has no production npm deps):
###   download a native-arm64 NW.js runtime, drop the source into
###   Contents/Resources/app.nw, brand the bundle, ad-hoc code-sign.
###
### NW.js version note:
###   0.77.0 (Chromium 114) is the newest-tested NW.js that STILL provides the
###   legacy chrome.serial / chrome.usb APIs this app depends on. NW.js >= ~0.80
###   removed them in favour of Web Serial (navigator.serial) / WebUSB
###   (navigator.usb); moving there requires porting js/chrome_serial.js and
###   js/libraries/stm32usbdfu.js (see MODERNIZATION.md).

NWJS_VERSION="0.77.0"
ARCH="arm64"
APP_NAME="KISS GUI"
BUNDLE_ID="com.flyduino.kissgui"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE_VERSION=$(node -p "require('$SCRIPT_DIR/package.json').version" 2>/dev/null || echo "2.0.34")
# Distinct identity for this native build (upstream GUI is $BASE_VERSION):
APP_VERSION="${BASE_VERSION}-arm64"

# Build outside the (iCloud) source tree to keep it fast and clean.
WORK="$HOME/kiss-gui-build"
CACHE="$WORK/cache"
NWJS_FILE="nwjs-v${NWJS_VERSION}-osx-${ARCH}"
NWJS_URL="https://dl.nwjs.io/v${NWJS_VERSION}/${NWJS_FILE}.zip"
OUT="$WORK/out"
APP="$OUT/${APP_NAME}.app"

mkdir -p "$CACHE" "$OUT"

echo "==> NW.js ${NWJS_VERSION} (osx-${ARCH})"
if [ ! -f "$CACHE/${NWJS_FILE}.zip" ]; then
    echo "    downloading $NWJS_URL"
    curl -L --fail -o "$CACHE/${NWJS_FILE}.zip" "$NWJS_URL"
fi
rm -rf "$CACHE/$NWJS_FILE"
unzip -q -o "$CACHE/${NWJS_FILE}.zip" -d "$CACHE"

echo "==> Assembling ${APP_NAME}.app"
rm -rf "$APP"
cp -R "$CACHE/$NWJS_FILE/nwjs.app" "$APP"

# Payload -> Contents/Resources/app.nw (exclude VCS / dev / build artifacts)
APPNW="$APP/Contents/Resources/app.nw"
mkdir -p "$APPNW"
rsync -a \
    --exclude '.git' --exclude '.gitignore' --exclude 'node_modules' \
    --exclude 'dist' --exclude 'apps' --exclude 'debug' --exclude 'release' \
    --exclude 'cache' --exclude 'yarn.lock' --exclude 'gulpfile.js' \
    --exclude 'build-macos-arm64.sh' \
    "$SCRIPT_DIR/" "$APPNW/"

echo "==> Branding bundle"
cp "$SCRIPT_DIR/images/icon_128.icns" "$APP/Contents/Resources/app.icns"
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_VERSION}" "$PLIST"

echo "==> Ad-hoc code signing (local use)"
# Strip any quarantine, then deep ad-hoc sign so Gatekeeper lets it run locally.
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"

echo ""
echo "==> Done: $APP"
echo "    arch: $(lipo -archs "$APP/Contents/MacOS/nwjs")"
echo "    Drag it to /Applications (replace the old crashing copy)."
