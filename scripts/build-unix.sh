#!/usr/bin/env bash
# build-unix.sh - FoundryMTR Launcher build driver (macOS / Linux)
# -----------------------------------------------------------------------------
# The launcher source is VENDORED at <repo>/launcher/ - this script no longer
# clones anything from upstream. It installs dependencies, enforces the
# canonical configuration (idempotent), deploys the theme, then launches or
# packages.
#
# Usage:
#   ./build-unix.sh                 # npm start
#   ./build-unix.sh --installer     # npm run dist:mac (on macOS) / dist:linux
#   ./build-unix.sh --clean         # wipe node_modules + dist first
#
# Canonical values: docs/REBRAND_TO_FOUNDRYMTR.md section 2.
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$REPO_DIR/launcher"

APP_NAME="FoundryMTR Launcher"
APP_ID="com.foundrymtr.launcher"
PUBLISHER="FoundryMC Services LLC"
SERVER_NAME="FoundryMTR"
DISTRIBUTION_URL="https://files.foundrymtr.com/helios/distribution.json"
AZURE_CLIENT_ID="6809b695-eb71-43f8-8fa5-5e9c7d7b33de"

CLEAN=0
INSTALLER=0
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --installer) INSTALLER=1 ;;
  esac
done

[ -d "$BUILD_DIR" ] || { echo "ERROR: launcher folder not found at $BUILD_DIR"; exit 1; }
echo "=== $APP_NAME build ==="
echo "Launcher: $BUILD_DIR"

if [ "$CLEAN" = "1" ]; then
  echo ">> Cleaning node_modules and dist..."
  rm -rf "$BUILD_DIR/node_modules" "$BUILD_DIR/dist"
fi

echo ">> Installing dependencies..."
cd "$BUILD_DIR"
if [ -f package-lock.json ]; then npm ci; else npm install; fi

echo ">> Enforcing canonical configuration..."
# distromanager.js distro URL (idempotent)
sed -i.bak -E "s#exports\.REMOTE_DISTRO_URL = '[^']*'#exports.REMOTE_DISTRO_URL = '$DISTRIBUTION_URL'#" app/assets/js/distromanager.js && rm -f app/assets/js/distromanager.js.bak
# ipcconstants.js Azure client id (idempotent)
sed -i.bak -E "s#exports\.AZURE_CLIENT_ID = '[^']*'#exports.AZURE_CLIENT_ID = '$AZURE_CLIENT_ID'#" app/assets/js/ipcconstants.js && rm -f app/assets/js/ipcconstants.js.bak
grep -q "FoundryMTR Launcher" package.json || echo "WARN: package.json productName drifted from canon"
grep -q "$APP_ID" electron-builder.yml || echo "WARN: electron-builder.yml appId drifted from canon"

echo ">> Deploying FoundryMTR theme assets..."
mkdir -p app/assets/css app/assets/js app/assets/images/backgrounds
cp "$REPO_DIR/branding/foundrymtr-theme.css" app/assets/css/foundrymtr-theme.css
cp "$REPO_DIR/branding/foundrymtr-news.js" app/assets/js/foundrymtr-news.js
cp "$REPO_DIR/branding/foundrymtr_station.jpg" app/assets/images/backgrounds/foundrymtr_station.jpg
grep -q "fmtrWireToggle" app/assets/js/foundrymtr-news.js && echo "  [OK] news widget deployed" || { echo "  [FAIL] news widget copy"; exit 1; }
grep -q "STATION-BOARD SIGNAGE THEME" app/assets/css/foundrymtr-theme.css && echo "  [OK] theme deployed" || { echo "  [FAIL] theme copy"; exit 1; }

if [ "$INSTALLER" = "1" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    echo ">> Building macOS installer (npm run dist:mac)..."
    npm run dist:mac
    echo "Expected output: dist/FoundryMTR-Setup-<version>-<arch>.dmg (+ .blockmap + latest-mac.yml)"
  else
    echo ">> Building Linux AppImage (npm run dist:linux)..."
    npm run dist:linux
    echo "Expected output: dist/FoundryMTR-Setup-<version>.AppImage (+ latest-linux.yml)"
  fi
else
  echo ">> Launching (npm start)..."
  npm start
fi
