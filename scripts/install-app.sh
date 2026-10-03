#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Slashlate"
SOURCE_APP="$ROOT_DIR/build/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"

bash "$ROOT_DIR/scripts/build-app.sh"

# Accessibility and Keychain grants survive the move only with a stable
# signature (same bundle ID + certificate). Ad-hoc builds must be re-granted.
if codesign -dv "$SOURCE_APP" 2>&1 | grep -q "Signature=adhoc"; then
    echo
    echo "WARNING: installing an ad-hoc signed build; Accessibility will need to be granted again."
fi

pkill -x "$APP_NAME" 2>/dev/null || true

mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
# ditto keeps the bundle and its code signature intact.
ditto "$SOURCE_APP" "$TARGET_APP"

open "$TARGET_APP"

echo
echo "Installed and launched:"
echo "$TARGET_APP"
echo "If 'Open Slashlate at login' was enabled from build/, turn it off and on"
echo "again in Settings so it points to this copy."
