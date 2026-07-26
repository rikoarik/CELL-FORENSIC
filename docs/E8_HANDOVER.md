# E8-04 / E8-05 — Handover & Sign-off

Tanggal: 2026-07-26 (diperbarui pasca-E9)  
Project: Cell Forensic  
Penerima: tim pengajar / fasilitator pilot / maintainer teknis

## 1. Apa yang diserahkan

| Artifact | Lokasi |
|---|---|
| Aplikasi siswa (Flutter Android) | `lib/main_mobile.dart` → APK via `scripts/release_android.sh` |
| Dashboard guru (Flutter Web) | `lib/main_dashboard.dart` → `scripts/release_web_dashboard.sh` |
| Skema & migrasi Supabase | `docs/supabase_schema.sql`, `supabase/migrations/` (termasuk E9) |
| Task registry | `docs/TASK-REGISTRY.yaml` (E0–E9) |
| Acceptance / regresi | `docs/E8_ACCEPTANCE.md` |
| Teacher auth & session lifecycle | `docs/E9_TEACHER_AUTH.md` |
| Epic notes E0–E7 | `docs/E0_*.md` … `docs/E7_*.md` |
| Requirement paket | `docs/00_README.md` → `01`…`12` |

## 2. Prasyarat mesin

- Flutter **stable** (CI memakai channel stable)
- Android SDK (untuk APK / `flutter run` device)
- Chrome (untuk dashboard web lokal)
- Akses proyek Supabase (URL + **anon/publishable** key saja)
- Akun guru di Auth + `profiles.role ∈ {teacher, admin}` (lihat E9)

```bash
cd /path/to/CellForensic
flutter pub get
dart analyze
flutter test   # opsional penuh; smoke: lihat E8_ACCEPTANCE.md
```

## 3. Environment & rahasia

Flutter membaca konfigurasi lewat `--dart-define` (bukan file `.env` di runtime app):

| Define | Wajib? | Keterangan |
|---|---|---|
| `SUPABASE_URL` | Disarankan prod | Default ada di `SupabaseConfig` untuk dev |
| `SUPABASE_ANON_KEY` | Disarankan prod | **Hanya** anon/publishable |
| `APP_FLAVOR` | Opsional | `dev` (default) · `staging` · `prod` |

```bash
# Contoh — ganti nilai; JANGAN pernah memakai service_role di client/CI secrets dashboard
export SUPABASE_URL='https://<project>.supabase.co'
export SUPABASE_ANON_KEY='<anon-or-publishable-key>'
```

Template salinan lokal tooling: `.env.example` (komentar menegaskan: no `service_role`).

GitHub Actions secrets untuk release manual: `SUPABASE_URL`, `SUPABASE_ANON_KEY` saja (lihat `.github/workflows/ci.yml`).

## 4. Menjalankan lokal

### Mobile (siswa)

```bash
flutter run -t lib/main_mobile.dart \
  --dart-define=APP_FLAVOR=dev \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Tanpa define Supabase yang valid, app tetap jalan offline dengan content pack lokal (join demo `CELL01`).

### Dashboard guru (web)

```bash
flutter run -d chrome -t lib/main_dashboard.dart \
  --dart-define=APP_FLAVOR=dev \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Login email/password guru diperlukan (`TeacherAuthGate`). Buat guru pertama: `docs/E9_TEACHER_AUTH.md` → `promote_user_to_teacher`.

## 5. Flavors

| Flavor | Penggunaan |
|---|---|
| `dev` | Default lokal |
| `staging` | Build web CI |
| `prod` | Release APK + web (`scripts/release_*.sh`) |

Implementasi: `lib/core/config/app_flavor.dart` (diuji di `test/core/config/app_flavor_test.dart`).

## 6. Supabase (ops / migrasi)

1. Terapkan migrasi berurutan di `supabase/migrations/` (foundation → E7 RLS → **E9 teacher auth**).
2. Seed / pastikan sesi aktif kode **`CELL01`** (atau buat sesi baru dari dashboard).
3. Promosikan akun guru (`promote_user_to_teacher`) — prosedur di `docs/E9_TEACHER_AUTH.md`.
4. Verifikasi: anon join via `join_active_session`; guru login + Buat/Aktifkan/Tutup Sesi.
5. Setelah kelas: **Tutup Sesi** di dashboard (`status = closed`) agar write siswa terkunci.

**Tidak** mendistribusikan `service_role` ke APK, web bundle, README client, atau secret yang dibaca Flutter.

## 7. Release & CI

| Langkah | Perintah / aksi |
|---|---|
| APK release | `./scripts/release_android.sh` → `build/app/outputs/flutter-apk/app-release.apk` |
| Web release | `./scripts/release_web_dashboard.sh` → `build/web/` |
| CI otomatis | Push/PR → `dart analyze` + `flutter test` + web staging build |
| CI artifak release | `workflow_dispatch` + `build_release=true` (butuh secrets anon) |

Detail: `docs/E7_RELEASE.md`.

Smoke pasca-release (manual):

1. Install APK → join `CELL01` → buka misi 1 (AR atau fallback 3D).
2. Buka dashboard hosted → **login guru** → sesi aktif + kelompok terlihat.
3. Network tab browser: hanya anon key (+ JWT session setelah login).

## 8. Alur produk (untuk fasilitator)

```text
Guru:  Login dashboard → Buat/Aktifkan sesi → bagikan join code
     → Ringkasan sesi → Detail kelompok → Review/skor → Ekspor CSV
     → Tutup Sesi setelah kelas

Siswa: Device check → Join kode → Kelompok → Onboarding
     → Misi 1–3 (+ AI + logbook) → Kesimpulan
     → POS 1–3 (marker/PIN, 5 menit) → Hasil
```

Runbook kelas: `docs/E7_PILOT_RUNBOOK.md`.  
Matriks perangkat: `docs/E7_DEVICE_MATRIX.md`.  
Auth & sesi: `docs/E9_TEACHER_AUTH.md`.

## 9. Known limitations & residual risks

| Area | Risiko / batasan | Mitigasi |
|---|---|---|
| RLS session-wide anon | Semua klien di sesi aktif bisa baca/tulis semua kelompok | Kelas tertutup; **Tutup Sesi** setelah kelas |
| Teacher auth (E9) | Sudah gated; residual: join-code spam RPC, `CELL01.teacher_id` null | Promosikan guru; buat sesi owned; awasi dashboard |
| Marker POS | Simulasi tombol, bukan computer vision | PIN fallback `1111`/`2222`/`3333` |
| Asset / animasi | 21 GLB (bukan 30); clip animasi/particle native terbatas | Sequence + swap model; fallback 3D |
| iOS / multiplayer AR | Out of scope MVP | — |
| Device matrix & pilot fisik | Checklist E7-03/E7-04 belum ditick | Wajib sebelum klaim “production classroom ready” |
| Admin CMS (FR-110+) | Tidak di MVP | Edit `local_content_pack` / migrasi SQL |
| Organel X/Y, membran 1/2 | Label provisional | Scoring/AI tidak mengunci sebagai fakta |

## 10. Sign-off proyek (E8-05)

| Peran | Kriteria | Status 2026-07-26 |
|---|---|---|
| Engineering | Analyze + smoke hijau; MVP wajib tertutup/partial terdokumentasi | **Signed (teknis)** |
| Security | RLS pilot + teacher policies E9; residual anon session-wide terdokumentasi | **Signed (dengan residual)** |
| Product / akademik | Pilot kelas + device matrix | **Pending fasilitator** (E7-03, E7-04) |

**Keputusan handover:** kode dan dokumentasi siap untuk **pilot kelas tertutup** (termasuk login guru + lifecycle sesi). Go-live produksi luas menunggu: (1) tick device matrix, (2) hasil pilot runbook, (3) pengetatan RLS per-kelompok / ownership siswa.

Kontak teknis: maintainer repositori Cell Forensic.  
Dokumen acceptance: `docs/E8_ACCEPTANCE.md`.  
Auth guru: `docs/E9_TEACHER_AUTH.md`.
