#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Slashlate"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

cd "$ROOT_DIR"

echo "Building $APP_NAME..."
swift build -c release --product "$APP_NAME"

BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc signatures change on every build, so macOS treats each rebuild as a
# new app and drops its Accessibility (TCC) grant and Keychain access. Set
# SLASHLATE_SIGN_IDENTITY (e.g. "Apple Development: you@example.com (TEAMID)")
# to sign with a stable identity and keep those grants across rebuilds.
SIGN_IDENTITY="${SLASHLATE_SIGN_IDENTITY:--}"

codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_BUNDLE"

echo
echo "Built:"
echo "$APP_BUNDLE"
