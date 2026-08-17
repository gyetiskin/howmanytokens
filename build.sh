#!/bin/bash
# Builds HowManyTokens and packages it into a runnable .app bundle.
# Usage: ./build.sh [--install]
#   --install  Also copy the bundle into /Applications.
set -euo pipefail

cd "$(dirname "$0")"

INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        *) echo "Unknown argument: $arg" >&2
           echo "Usage: ./build.sh [--install]" >&2
           exit 2 ;;
    esac
done

if ! command -v swift >/dev/null 2>&1; then
    echo "swift not found. Install Xcode or the Command Line Tools:" >&2
    echo "    xcode-select --install" >&2
    exit 1
fi

APP_NAME="HowManyTokens"
BUNDLE_ID="com.howmanytokens.menubar"
VERSION="1.0.0"
BUILD_DIR="dist"
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> Building (release)"
swift build -c release

echo "==> Packaging $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# LSUIElement keeps the app out of the Dock and the app menu; it lives in the
# status bar only.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

if [[ "$INSTALL" == 1 ]]; then
    echo "==> Installing into /Applications"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "Installed: /Applications/$APP_NAME.app"
else
    echo "Ready: $APP"
    echo "To install: ./build.sh --install"
fi
