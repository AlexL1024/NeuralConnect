#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROJECT_PATH="${PROJECT_PATH:-$ROOT/NeuralConnect.xcodeproj}"
SCHEME="${SCHEME:-NeuralConnect}"
CONFIGURATION="${CONFIGURATION:-Debug}"

# iPhone 16 Pro (from `xcrun xctrace list devices`)
DEVICE_ID="${DEVICE_ID:-00008140-000A70422E44801C}"
SDK="${SDK:-iphoneos26.2}"
BUNDLE_ID="${BUNDLE_ID:-com.MrPolpo.NeuralConnect}"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/.derivedData-device}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/${SCHEME}.app"

echo "[deploy] Building ${SCHEME} (${CONFIGURATION}) for device ${DEVICE_ID}…"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk "$SDK" \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "[deploy] ERROR: built app not found at: $APP_PATH" >&2
  exit 2
fi

echo "[deploy] Installing…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "[deploy] Launching…"
xcrun devicectl device process launch --terminate-existing --device "$DEVICE_ID" "$BUNDLE_ID" >/dev/null || true

echo "[deploy] Done."

