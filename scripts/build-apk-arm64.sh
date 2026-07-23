#!/usr/bin/env bash
# M38 — Build APK ringkas (arm64-only, obfuscated, shrinked).
# Target: HP Android 10+ modern (semua arm64). Ukuran ~55–70MB
# (turun dari ~193MB fat APK).
set -euo pipefail

cd "$(dirname "$0")/.."

flutter clean
flutter pub get

flutter build apk \
  --release \
  --target-platform android-arm64 \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=build/debug-info \
  "$@"

echo ""
echo "✅ APK arm64 selesai. Output:"
ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
