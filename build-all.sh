#!/usr/bin/env bash
#
# build-all.sh — Opsi 2: satu site Netlify, dua path.
#
#   /       -> app siswa   (lib/main.dart)
#   /guru/  -> dashboard   (lib/main_dashboard.dart)
#
# Hasil akhir ada di folder dist/
#
# Env wajib — samakan dengan scripts/vercel_build.sh. Tanpa ini build
# akan diam-diam memakai nilai default di lib/core/supabase/supabase_config.dart.
#
#   SUPABASE_URL, SUPABASE_ANON_KEY
#
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL di Netlify Environment Variables}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY di Netlify Environment Variables}"

OUT="dist"

# Dipakai kedua target supaya siswa dan guru menunjuk ke backend yang sama.
DEFINES=(
  --dart-define=APP_FLAVOR=prod
  --dart-define="SUPABASE_URL=$SUPABASE_URL"
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
)

echo "▶ Bersihkan output lama"
rm -rf "$OUT"

echo "▶ flutter pub get"
flutter pub get

# ---------------------------------------------------------------
# 1. App siswa -> root
# ---------------------------------------------------------------
echo "▶ Build siswa (lib/main.dart) dengan base-href /"
flutter build web --release \
  --target lib/main.dart \
  --base-href / \
  "${DEFINES[@]}"

cp -r build/web "$OUT"

# ---------------------------------------------------------------
# 2. Dashboard guru -> /guru/
# ---------------------------------------------------------------
echo "▶ Build guru (lib/main_dashboard.dart) dengan base-href /guru/"
flutter build web --release \
  --target lib/main_dashboard.dart \
  --base-href /guru/ \
  "${DEFINES[@]}"

cp -r build/web "$OUT/guru"

# ---------------------------------------------------------------
# 3. _redirects gabungan
#
# File web/_redirects (kalau ada) ikut tersalin ke dist/ dan
# dist/guru/. Yang di subfolder diabaikan Netlify, dan yang di root
# harus berisi aturan untuk KEDUA app — jadi kita timpa di sini.
# Urutan penting: rule paling spesifik harus di atas.
# ---------------------------------------------------------------
echo "▶ Tulis $OUT/_redirects"
rm -f "$OUT/guru/_redirects"
cat > "$OUT/_redirects" <<'EOF'
/guru/*   /guru/index.html   200
/*        /index.html        200
EOF

echo "✓ Selesai"
du -sh "$OUT" "$OUT/guru"
