# E8-01 / E8-03 — Final Acceptance & Regression

Tanggal: 2026-07-26  
Project: Cell Forensic (Flutter 3.0)

Dokumen ini memverifikasi deliverable E0–E7 terhadap paket requirement asli (`docs/01_PRD.md` … `11_MVP_ROADMAP.md`) dan mencatat hasil regresi otomatis. Slice pasca-handover **E9** (teacher auth + session CRUD) sudah menutup FR-001/003 — lihat `docs/E9_TEACHER_AUTH.md`. Checklist operasional perangkat/kelas tetap di E7 (belum ditick fisik).

## 1. MVP wajib (`11_MVP_ROADMAP.md`)

| Item MVP | Status | Bukti |
|---|---|---|
| Flutter Android (siswa) | **Pass** | `lib/main_mobile.dart`, release APK `scripts/release_android.sh` |
| Flutter Web dashboard | **Pass** | `lib/main_dashboard.dart`, `docs/E6_TEACHER_DASHBOARD.md` |
| Tiga misi | **Pass** | SEQ-MISI-1/2/3 + `MissionScreen` (`docs/E3_AR_INVESTIGATION.md`) |
| LKPD lengkap | **Pass** | Logbook 4 prompt/misi + kesimpulan/hipotesis (`docs/E4_AI_LKPD.md`) |
| POS 1–3 | **Pass** | Marker simulasi + PIN, timer 300 dtk (`docs/E5_EVALUATION_STATIONS.md`) |
| Offline-first | **Pass** | `SessionSnapshotStore` + `SyncQueue`; Supabase opsional |
| Fallback 3D | **Pass** | `model_viewer_plus` + `FakeArSceneEngine` |
| Supabase + RLS | **Pass (pilot)** | Schema + migrasi E7/E9; residual anon session-wide di `docs/E7_RLS_SECURITY.md` + `E9_TEACHER_AUTH.md` |

## 2. Traceability FR (ringkas)

Legenda: **OK** = terimplementasi untuk MVP pilot · **Partial** = ada jalur MVP dengan batasan · **Out** = di luar MVP / ditunda · **Ops** = butuh checklist fisik

### Auth & sesi

| ID | Ringkas | Status | Catatan |
|---|---|---|---|
| FR-001 | Guru login email | **OK (E9)** | Email/password + `profiles.role`; lihat `docs/E9_TEACHER_AUTH.md` |
| FR-002 | Join kode sesi | **OK** | `CELL01` lokal + `join_active_session` remote RPC |
| FR-003 | Guru buat sesi | **OK (E9)** | Dashboard Buat Sesi / Aktifkan / Tutup |
| FR-004–006 | Kelompok & anggota | **OK** | Create/join/promote leader (`docs/E2_SESSION_GROUP.md`) |

### Device & AR

| ID | Ringkas | Status | Catatan |
|---|---|---|---|
| FR-010–011 | Cek AR / fallback 3D | **OK** | `DeviceCheckScreen` + Model Viewer |
| FR-012 | Tutorial | **OK** | Onboarding journey |
| FR-020–025 | Scan, place, reset, tracking | **OK** | Plane + anchor; recovery pause (`E3`) |
| FR-040–064 | Misi 1–3 visual | **Partial** | Sequence + asset swap; glow/particle/animasi native terbatas (E0 spike: anim/particle gagal atau diganti asset) |
| FR-121–123 | Abstraksi AR | **OK** | `ArSceneEngine` + lifecycle channel docs E7 |

### AI & LKPD

| ID | Ringkas | Status | Catatan |
|---|---|---|---|
| FR-030 | Chat teks | **OK** | |
| FR-031 | Suara | **Out** | Opsional; tidak di MVP |
| FR-032–035 | Intent + fakta terkunci | **OK** | `IntentMatcher` + guard provisional X/Y |
| FR-070–079 | Logbook + autosave/sync | **OK** | |
| FR-080–083 | Kesimpulan | **OK** | Validasi field wajib |

### POS & dashboard

| ID | Ringkas | Status | Catatan |
|---|---|---|---|
| FR-090 | Guru mulai fase POS | **Partial** | Siswa unlock via journey; gate guru eksplisit belum |
| FR-091–096 | Marker/PIN/timer/rotasi/kunci | **OK** | Marker = simulasi tombol (bukan CV) |
| FR-100–106 | Overview…CSV | **OK** | `docs/E6_TEACHER_DASHBOARD.md` |
| FR-110–115 | Admin CMS | **Out** | Content pack lokal; admin UI tidak di MVP |

## 3. NFR & arsitektur (spot-check)

| Tema | Status | Referensi |
|---|---|---|
| Offline saat koneksi lemah | **OK** | Snapshot lokal + sync queue |
| Anti-halusinasi AI / skor | **OK** | Intent terkunci + `ScoringEngine` provisional |
| Keamanan RLS kelas tertutup | **Partial** | Session-wide anon; lihat E7 residual |
| Perf ≥30 FPS AR | **Ops** | Device matrix E7-03 belum ditick fisik |
| CI analyze + test | **OK** | `.github/workflows/ci.yml` |

## 4. E8-03 — Regresi otomatis (2026-07-26)

Perintah:

```bash
dart analyze
flutter test \
  test/core/config/app_flavor_test.dart \
  test/ar/ar_lifecycle_controller_test.dart \
  test/features/session/persisted_session_repository_test.dart \
  test/features/journey/student_journey_test.dart \
  test/domain/scoring/scoring_engine_test.dart \
  test/app/dashboard_app_test.dart \
  test/features/dashboard/dashboard_csv_exporter_test.dart
```

Hasil:

| Suite | Hasil |
|---|---|
| `dart analyze` | **No issues found** |
| Smoke subset (40 tests) | **All tests passed** |

Cakupan smoke: flavor, AR lifecycle, session persist, journey end-to-end (misi→POS→hasil), scoring, dashboard + CSV.

Regresi penuh CI: `flutter test` di job `analyze_and_test` (lihat `docs/E7_RELEASE.md`).

## 5. E8-02 — Pilot blockers & bug final

Tidak ditemukan blocker kode dari analyze/smoke pada tanggal di atas.

| Item | Jenis | Tindakan |
|---|---|---|
| Device matrix fisik (ARCore fleet) | **Ops** | Facilitator mengisi `docs/E7_DEVICE_MATRIX.md` |
| Classroom pilot live | **Ops** | Facilitator mengisi result log di `docs/E7_PILOT_RUNBOOK.md` |
| Teacher JWT / create-session UI | **Done (E9)** | Login + Buat/Aktifkan/Tutup Sesi; residual = session-wide anon RLS siswa |
| Animasi clip / particle native | **Known limit E0** | Fallback asset/sequence; bukan blocker gameplay |

Tidak ada patch kode E8-02 pada rilis handover ini.

## 6. Sign-off teknis (otomatis)

| Kriteria | Status |
|---|---|
| Requirement MVP wajib tertutup atau partial dengan alasan | **Ya** |
| Regresi analyze + smoke hijau | **Ya** |
| Blocker kode kritis terbuka | **Tidak** |
| Siap pilot kelas tertutup (dengan residual RLS) | **Ya — pending E7-03/E7-04 fisik** |

Lihat juga: `docs/E8_HANDOVER.md`.
