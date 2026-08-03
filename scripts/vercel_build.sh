#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_ROOT="$PROJECT_ROOT/.flutter-sdk"

cd "$PROJECT_ROOT"

: "${SUPABASE_URL:?Set SUPABASE_URL in Vercel Environment Variables}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY in Vercel Environment Variables}"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  git clone \
    --depth 1 \
    --branch stable \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web \
  --target lib/main.dart \
  --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
