#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/build/Slashlate.app"

bash "$ROOT_DIR/scripts/build-app.sh"

pkill -x Slashlate 2>/dev/null || true
open "$APP_BUNDLE"

echo "Slashlate launched."
