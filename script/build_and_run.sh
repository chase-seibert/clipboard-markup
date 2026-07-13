#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="ClipboardMarkup"
BUNDLE_NAME="Clipboard Markup"
BUNDLE_ID="com.chaseseibert.ClipboardMarkup"
LOGIN_LAUNCHER_NAME="ClipboardMarkupLoginLauncher"
LOGIN_LAUNCHER_BUNDLE_NAME="Clipboard Markup Login Launcher"
LOGIN_LAUNCHER_BUNDLE_ID="com.chaseseibert.ClipboardMarkup.LoginLauncher"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="0.1.0"
APP_BUILD="1"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
LOGIN_ITEMS_DIR="$APP_CONTENTS/Library/LoginItems"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
ANALYTICS_CONFIG_FILE="$ROOT_DIR/Config/AnalyticsConfig.local.plist"
LOGIN_LAUNCHER_BUNDLE="$LOGIN_ITEMS_DIR/$LOGIN_LAUNCHER_NAME.app"
LOGIN_LAUNCHER_CONTENTS="$LOGIN_LAUNCHER_BUNDLE/Contents"
LOGIN_LAUNCHER_MACOS="$LOGIN_LAUNCHER_CONTENTS/MacOS"
LOGIN_LAUNCHER_BINARY="$LOGIN_LAUNCHER_MACOS/$LOGIN_LAUNCHER_NAME"
LOGIN_LAUNCHER_INFO_PLIST="$LOGIN_LAUNCHER_CONTENTS/Info.plist"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --product "$APP_NAME"
swift build --product "$LOGIN_LAUNCHER_NAME"
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
LOGIN_LAUNCHER_BUILD_BINARY="$BUILD_DIR/$LOGIN_LAUNCHER_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$LOGIN_LAUNCHER_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$LOGIN_LAUNCHER_BUILD_BINARY" "$LOGIN_LAUNCHER_BINARY"
chmod +x "$APP_BINARY"
chmod +x "$LOGIN_LAUNCHER_BINARY"

if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"
fi

if [[ -f "$ANALYTICS_CONFIG_FILE" ]]; then
  cp "$ANALYTICS_CONFIG_FILE" "$APP_RESOURCES/AnalyticsConfig.plist"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat >"$LOGIN_LAUNCHER_INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$LOGIN_LAUNCHER_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$LOGIN_LAUNCHER_BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$LOGIN_LAUNCHER_BUNDLE_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$LOGIN_LAUNCHER_BUNDLE_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --sign "$SIGN_IDENTITY" "$LOGIN_LAUNCHER_BUNDLE" >/dev/null
/usr/bin/codesign --force --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
