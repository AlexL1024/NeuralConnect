#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_SCRIPT="${DEPLOY_SCRIPT:-$ROOT/scripts/deploy_16pro.sh}"

POLL_SECONDS="${POLL_SECONDS:-1}"
QUIET_SECONDS="${QUIET_SECONDS:-2}"

LOCK_FILE="$ROOT/.deploy.lock"

watch_mtime() {
  # shellcheck disable=SC2016
  find "$ROOT/NeuralConnect" "$ROOT/Packages" "$ROOT/NeuralConnect.xcodeproj" \
    -type f \
    \( -name '*.swift' -o -name '*.plist' -o -name '*.storyboard' -o -name '*.xib' -o -name '*.sks' -o -name '*.json' -o -name '*.pbxproj' -o -name '*.xcconfig' -o -name '*.metal' -o -name '*.png' -o -name '*.jpg' \) \
    -print0 2>/dev/null \
  | xargs -0 stat -f '%m' 2>/dev/null \
  | sort -n \
  | tail -n 1
}

last="$(watch_mtime || echo 0)"
echo "[watch] Starting. Poll=${POLL_SECONDS}s, Quiet=${QUIET_SECONDS}s"
echo "[watch] Deploy script: $DEPLOY_SCRIPT"

rm -f "$LOCK_FILE"

while true; do
  sleep "$POLL_SECONDS"
  now="$(watch_mtime || echo 0)"
  if [[ "$now" -le "$last" ]]; then
    continue
  fi
  last="$now"

  # Debounce: wait for edits to settle.
  sleep "$QUIET_SECONDS"
  after="$(watch_mtime || echo 0)"
  if [[ "$after" -gt "$last" ]]; then
    last="$after"
    continue
  fi

  if [[ -e "$LOCK_FILE" ]]; then
    continue
  fi

  : > "$LOCK_FILE"
  echo "[watch] Change detected -> deploy…"
  set +e
  "$DEPLOY_SCRIPT"
  code=$?
  set -e
  rm -f "$LOCK_FILE"

  if [[ $code -ne 0 ]]; then
    echo "[watch] Deploy failed (exit $code). Waiting for next change…"
  fi
done

