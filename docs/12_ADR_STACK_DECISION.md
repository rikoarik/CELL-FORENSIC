# ADR — Flutter sebagai Stack Utama

## Status

Accepted.

## Keputusan

Gunakan Flutter untuk:
- Aplikasi siswa.
- Seluruh UI dan domain logic.
- Offline data dan sinkronisasi.
- Dashboard guru/admin melalui Flutter Web.

Target MVP tetap Android.

## AR

Akses AR ditempatkan di belakang abstraksi scene (`MissionScenePanel` / `ArSceneEngine`).

Urutan keputusan (E0 closed — lihat `docs/E0_AR_SPIKE_REPORT.md`):
1. Uji plugin Flutter melalui spike. → **MVP memakai `ar_flutter_plugin_2`.**
2. Jika seluruh kebutuhan kritis lulus, gunakan plugin. → **plane tap + load GLB lokal diterima untuk alur misi.**
3. Jika tidak, pertahankan Flutter sebagai application shell dan implementasikan renderer Android ARCore melalui Platform Channel. → **E0-05 deferred.**
4. Sediakan fallback 3D untuk perangkat tanpa AR. → **`model_viewer_plus` pada Mode 3D.**

## Alasan

- Satu bahasa dan pola UI untuk mobile serta dashboard.
- Logbook, form, state, dan business logic lebih mudah dibagi.
- Potensi iOS tetap terbuka.
- Tim tidak perlu membangun seluruh aplikasi native Android.
- Risiko AR dikelola melalui abstraction dan native bridge fallback.

## Konsekuensi

Positif:
- Codebase utama Dart.
- UI mobile dan web konsisten.
- Form dan offline flow lebih cepat dibangun.
- Backend Supabase mudah dipakai bersama.

Negatif:
- AR kompleks mungkin tetap memerlukan native Android.
- Platform view dan channel perlu diuji ketat.
- iOS tidak otomatis siap hanya karena aplikasi menggunakan Flutter.
- Renderer final baru dapat ditentukan setelah spike.

## Decision gate Phase 0

Wajib dibuktikan:
- Memuat 30 asset atau subset aktif dengan manifest.
- Plane detection dan anchor.
- Smooth zoom.
- Transparency.
- Glow.
- Animation clip.
- Particle system.
- Marker POS.
- Tracking recovery.
- Minimal 30 FPS.
- Lifecycle background/resume.
- Fallback 3D.

## Tidak digunakan

- Kotlin sebagai codebase aplikasi utama.
- Expo/React Native.
- Flutter Web untuk gameplay AR.
