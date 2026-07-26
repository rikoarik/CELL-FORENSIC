#!/usr/bin/env bash
# E7-05 — Release student Android APK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${SUPABASE_URL:?Set SUPABASE_URL (publishable project URL)}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY (anon/publishable key — never service_role)}"

FLAVOR="${APP_FLAVOR:-prod}"
ENTRY="${ENTRYPOINT:-lib/main_mobile.dart}"

echo "==> flutter pub get"
flutter pub get

echo "==> dart analyze"
dart analyze

echo "==> flutter build apk ($ENTRY, flavor=$FLAVOR)"
flutter build apk \
  -t "$ENTRY" \
  --release \
  --dart-define="APP_FLAVOR=$FLAVOR" \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

APK="build/app/outputs/flutter-apk/app-release.apk"
echo "==> Done: $APK"
ls -lh "$APK"
