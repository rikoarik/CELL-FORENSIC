#!/usr/bin/env bash
# E7-05 — Release Flutter Web teacher dashboard.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${SUPABASE_URL:?Set SUPABASE_URL (publishable project URL)}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY (anon/publishable key — never service_role)}"

FLAVOR="${APP_FLAVOR:-prod}"

echo "==> flutter pub get"
flutter pub get

echo "==> dart analyze"
dart analyze

echo "==> flutter build web (lib/main_dashboard.dart, flavor=$FLAVOR)"
flutter build web \
  -t lib/main_dashboard.dart \
  --release \
  --dart-define="APP_FLAVOR=$FLAVOR" \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

echo "==> Done: build/web/"
ls -lh build/web/index.html
