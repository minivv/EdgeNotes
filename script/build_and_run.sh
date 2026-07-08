#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="EdgeNotes"
BUNDLE_ID="com.codex.EdgeNotes"
APP_VERSION="${APP_VERSION:-0.1.0}"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Sources/EdgeNotes/Resources/EdgeNotes.icns"
APP_ICON_PNG="$ROOT_DIR/Sources/EdgeNotes/Resources/EdgeNotesIcon.png"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --package-path "$ROOT_DIR"
BUILD_BINARY="$(swift build --package-path "$ROOT_DIR" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [ -f "$APP_ICON" ]; then
  cp "$APP_ICON" "$APP_RESOURCES/EdgeNotes.icns"
fi

if [ -f "$APP_ICON_PNG" ]; then
  cp "$APP_ICON_PNG" "$APP_RESOURCES/EdgeNotesIcon.png"
fi

for resource_bundle in "$(dirname "$BUILD_BINARY")"/"${APP_NAME}"_*.bundle; do
  [ -e "$resource_bundle" ] || continue
  cp -R "$resource_bundle" "$APP_RESOURCES/"
done

rm -rf "$APP_RESOURCES/themes"
mkdir -p "$APP_RESOURCES/themes"

copy_theme_file() {
  local theme_file="$1"
  [ -e "$theme_file" ] || return 0
  local theme_name
  theme_name="$(basename "$theme_file")"
  theme_name="${theme_name%.edgetheme}"
  theme_name="${theme_name%.sntheme}"
  cp "$theme_file" "$APP_RESOURCES/themes/$theme_name.edgetheme"
}

if [ -d "$ROOT_DIR/themes" ]; then
  for theme_file in "$ROOT_DIR"/themes/*.edgetheme "$ROOT_DIR"/themes/*.sntheme; do
    [ -e "$theme_file" ] || continue
    copy_theme_file "$theme_file"
  done
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
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>EdgeNotes</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build|--build)
    ;;
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
    echo "usage: $0 [run|--build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
