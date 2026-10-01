#!/bin/bash
# Builds dist/Curtain.app. Set CURTAIN_ARCHS to "host" for a faster
# single-architecture build; the default is a universal binary.
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHS="${CURTAIN_ARCHS:-universal}"
case "$ARCHS" in universal) ARCHS="arm64 x86_64" ;; host) ARCHS="$(uname -m)" ;; esac
FLAGS=(); for a in $ARCHS; do FLAGS+=(--arch "$a"); done

swift build -c release "${FLAGS[@]}"
BIN_DIR="$(swift build -c release "${FLAGS[@]}" --show-bin-path)"
APP="$PWD/dist/Curtain.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Curtain" "$APP/Contents/MacOS/Curtain"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
IDENTITY="${CURTAIN_SIGNING_IDENTITY:--}"
SIGN=(--force --sign "$IDENTITY" --options runtime --entitlements Resources/Curtain.entitlements)
[[ "$IDENTITY" == - ]] || SIGN+=(--timestamp)
/usr/bin/codesign "${SIGN[@]}" "$APP"
/usr/bin/codesign --verify --strict "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Curtain"))"
