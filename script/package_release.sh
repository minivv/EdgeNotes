#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="EdgeNotes"
APP_BUNDLE="$ROOT_DIR/outputs/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/$APP_NAME-macOS.zip"

"$ROOT_DIR/script/build_and_run.sh" --build

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc "$APP_BUNDLE" "$ZIP_PATH"
(cd "$DIST_DIR" && shasum -a 256 "$APP_NAME-macOS.zip" > "$APP_NAME-macOS.zip.sha256")

echo "$ZIP_PATH"
