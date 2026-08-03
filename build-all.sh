
#!/usr/bin/env bash
#
# build-all.sh — Opsi 2: satu site Netlify, dua path.
#
#   /       -> app siswa   (lib/main.dart)
#   /guru/  -> dashboard   (lib/main_dashboard.dart)
#
# Hasil akhir ada di folder dist/
#
set -euo pipefail

OUT="dist"

echo "▶ Bersihkan output lama"
rm -rf "$OUT"

# ---------------------------------------------------------------
# 1. App siswa -> root
# ---------------------------------------------------------------
echo "▶ Build siswa (lib/main.dart) dengan base-href /"
flutter build web --release \
  --target lib/main.dart \
  --base-href /

cp -r build/web "$OUT"

# ---------------------------------------------------------------
# 2. Dashboard guru -> /guru/
# ---------------------------------------------------------------
echo "▶ Build guru (lib/main_dashboard.dart) dengan base-href /guru/"
flutter build web --release \
  --target lib/main_dashboard.dart \
  --base-href /guru/

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