# CELL FORENSIC — Full Documentation Package Flutter

Paket ini menjadi acuan pembangunan ulang Cell Forensic sebagai aplikasi pembelajaran AR berbasis kelompok menggunakan Flutter.

## Keputusan teknologi

- Aplikasi siswa: **Flutter Mobile** dengan Dart.
- Target MVP: **Android**.
- Target lanjutan: iOS setelah kemampuan AR tervalidasi.
- AR: `ar_flutter_plugin_2` + fallback `model_viewer_plus` (adapter `ArSceneEngine`); native ARCore bridge ditunda (E0-05).
- Dashboard guru/admin: **Flutter Web** dengan **login guru** (email/password + `profiles.role`).
- Backend: Supabase (RLS active-session + teacher policies; lihat E7/E9).
- Penyimpanan lokal: `SharedPreferences` + antrean sinkronisasi offline (`SyncQueue`); bukan SQLite di runtime saat ini.
- Aktivitas utama: kelompok, bukan siswa individual.
- Asset 3D: **21 GLB** terinventarisasi (bukan ~30 dokumen awal); lihat `10_ASSET_INVENTORY_AUDIT.md` / `asset_inventory.csv`.

## Dokumen

1. `01_PRD.md`
2. `02_FUNCTIONAL_REQUIREMENTS.md`
3. `03_NON_FUNCTIONAL_REQUIREMENTS.md`
4. `04_USER_FLOW_GAMEPLAY.md`
5. `05_SYSTEM_ARCHITECTURE_FLUTTER.md`
6. `06_FLUTTER_AR_IMPLEMENTATION_NOTES.md`
7. `07_DATABASE_SCHEMA.md`
8. `08_API_CONTRACT.md`
9. `09_LKPD_EVALUATION_SCORING.md`
10. `10_ASSET_INVENTORY_AUDIT.md`
11. `11_MVP_ROADMAP.md`
12. `12_ADR_STACK_DECISION.md`
13. `TASK-REGISTRY.yaml`
14. `openapi.yaml`
15. `supabase_schema.sql`

### Catatan epic implementasi (E0–E9)

- `E0_AR_SPIKE_REPORT.md` … `E7_*.md` — bukti per epic
- `E8_ACCEPTANCE.md` — verifikasi requirement + regresi final
- `E8_HANDOVER.md` — panduan operasional & sign-off handover
- `E9_TEACHER_AUTH.md` — auth guru, CRUD sesi, join RPC, RLS teacher

Status terkini: `TASK-REGISTRY.yaml` (E0–E6/E8/E9 **done**; E7 **partial** — device matrix & pilot fisik masih checklist).

## Sumber requirement

- Skenario CELL FORENSIC.
- Lembar Kerja Forensik Sel.
- Lembar Evaluasi POS 1–3.

## Prinsip

1. Event AR harus deterministik dan dapat diuji.
2. AI tidak boleh mengubah fakta biologis inti.
3. Gameplay inti harus tetap berjalan saat koneksi tidak stabil.
4. Perangkat yang tidak mendukung AR memakai fallback 3D.
5. Asset yang sudah ada dipakai ulang bila lolos audit.
6. Kode Flutter tidak boleh bergantung langsung pada satu plugin AR; akses AR melalui abstraction layer.
