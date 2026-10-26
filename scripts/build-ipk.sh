#!/usr/bin/env bash
# Build the Custom Home app into an installable .ipk
#
# Requires the webOS CLI (ares-cli):
#   npm install -g @webosose/ares-cli
#
# Usage:  ./scripts/build-ipk.sh
# Output: ./dist/com.tstef.customhome_1.0.0_all.ipk
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/launcher-app"
OUT="$ROOT/dist"

if ! command -v ares-package >/dev/null 2>&1; then
  echo " error: ares-package not found. Install it with:" >&2
  echo "  npm install -g @webosose/ares-cli" >&2
  exit 1
fi

mkdir -p "$OUT"
echo "Packaging $APP_DIR -> $OUT"
ares-package "$APP_DIR" -o "$OUT"
echo "Done:"
ls -1 "$OUT"/*.ipk
