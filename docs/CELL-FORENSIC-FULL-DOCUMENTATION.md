# CELL FORENSIC — Full Documentation Package Flutter


---

<!-- FILE: 00_README.md -->

# CELL FORENSIC — Full Documentation Package Flutter

Paket ini menjadi acuan pembangunan ulang Cell Forensic sebagai aplikasi pembelajaran AR berbasis kelompok menggunakan Flutter.

## Keputusan teknologi

- Aplikasi siswa: **Flutter Mobile** dengan Dart.
- Target MVP: **Android**.
- Target lanjutan: iOS setelah kemampuan AR tervalidasi.
- AR: lapisan Flutter dengan adapter AR; jika plugin Flutter tidak memenuhi kebutuhan, gunakan modul native Android ARCore melalui Platform Channel.
- Dashboard guru/admin: **Flutter Web**.
- Backend: Supabase.
- Penyimpanan lokal: database SQLite-backed dan antrean sinkronisasi offline.
- Aktivitas utama: kelompok, bukan siswa individual.
- Asset 3D: sekitar 30 asset sudah tersedia dan harus diaudit sebelum integrasi.

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


---

<!-- FILE: 01_PRD.md -->

# Product Requirements Document — Cell Forensic

## 1. Ringkasan

Cell Forensic adalah aplikasi pembelajaran AR berbasis Flutter yang menempatkan siswa sebagai tim penyelidik forensik sel. Siswa memindai meja, memunculkan laboratorium virtual, mengamati dua sampel sel rusak, bertanya kepada Asisten AI Lab, mengisi logbook, membuat identifikasi dan hipotesis, lalu menyelesaikan tiga pos evaluasi.

## 2. Sampel

### Sampel A — Sel Tumbuhan
- Bentuk kotak dan kaku.
- Memiliki dinding sel.
- Kloroplas menyusut.
- Vakuola raksasa mengempes.
- Kondisi tampak layu dan warna memudar.

### Sampel B — Sel Hewan
- Bentuk bulat/tidak beraturan.
- Tidak memiliki dinding sel.
- Membran fosfolipid robek.
- Cairan sel bocor keluar.
- Kondisi tampak mengkerut/kempes.

## 3. Tujuan pembelajaran

Siswa mampu:
1. Membedakan sel tumbuhan dan sel hewan.
2. Menjelaskan fungsi kloroplas dan vakuola.
3. Menjelaskan fosfolipid bilayer dan selektif permeabel.
4. Menjelaskan fungsi dinding sel dan selulosa.
5. Menganalisis dampak kerusakan struktur sel.
6. Menyusun hipotesis berdasarkan bukti visual.
7. Menerapkan konsep pada kasus ekosistem dan hewan.

## 4. Target pengguna

### Siswa
- Bergabung ke sesi.
- Membentuk kelompok.
- Menjalankan AR.
- Bertanya lewat teks/suara.
- Mengisi logbook.
- Menyelesaikan evaluasi.

### Guru
- Membuat sesi dan kelompok.
- Memantau progres.
- Meninjau jawaban.
- Memberi skor dan feedback.

### Admin
- Mengelola akun, konten, pertanyaan, rubrik, trigger, dan asset.

## 5. Platform dan Teknologi

- Flutter Mobile untuk aplikasi siswa.
- Android menjadi target MVP.
- Flutter Web untuk dashboard guru/admin.
- Supabase untuk authentication, PostgreSQL, storage, dan backend function.
- AR dijalankan melalui adapter Flutter. Implementasi dapat memakai plugin Flutter yang lolos spike atau native ARCore bridge melalui Platform Channel.
- Asset 3D GLB/GLTF memakai sekitar 30 file yang telah tersedia.
- Mode fallback menampilkan scene 3D non-AR dengan gameplay yang sama.

## 6. Scope

### In scope
- Android AR.
- Surface detection.
- Dua sampel sel.
- Tiga misi.
- AI intent/keyword trigger.
- Logbook digital.
- Identifikasi dan hipotesis.
- POS 1–3 dengan marker atau PIN fallback.
- Timer lima menit.
- Dashboard guru.
- Supabase.
- Fallback 3D non-AR.

### Out of scope MVP
- Multiplayer AR sinkron.
- iOS.
- AI generatif bebas.
- LMS integration.
- Cloud anchors.
- Penilaian esai sepenuhnya otomatis.
- Pembuatan asset 3D baru jika asset lama sudah layak.

## 7. Misi

### Misi 1
Memeriksa organel Sampel A.

Trigger intent:
`inspect_sample_a_organel`

Output:
- Smooth zoom.
- Glow kuning.
- Kloroplas menyusut.
- Vakuola mengempes.
- Prompt analisis fungsi dan dampak.

### Misi 2
Memeriksa membran Sampel B.

Trigger intent:
`inspect_sample_b_membrane`

Output:
- Zoom ke membran.
- Fosfolipid bilayer robek.
- Particle system cairan biru.
- Prompt selektif permeabel.

### Misi 3
Membandingkan lapisan luar.

Trigger intent:
`compare_outer_layers`

Output:
- Side-by-side.
- Dinding sel hijau.
- Tanda silang merah pada Sampel B.
- Panah indikator tekanan.

## 8. Evaluasi POS

### POS 1
- Identifikasi organel X dan Y.
- Dampak kerusakan massal terhadap ekosistem dan rantai makanan.

### POS 2
- Identifikasi bagian membran nomor 1 dan 2.
- Analisis zat lipofilik dan selektif permeabel.

### POS 3
- Perbedaan Sampel A dan B.
- Analisis klaim suplemen selulosa untuk kucing/anjing.

## 9. Success criteria

- Seluruh tiga misi dapat diselesaikan.
- Jawaban tidak hilang saat offline.
- Asset berjalan minimal 30 FPS pada perangkat target.
- Guru dapat melihat hasil semua kelompok.
- Kelompok dapat menyelesaikan POS dengan timer.
- Tidak ada event AR salah akibat pertanyaan ambigu.

## 10. Risiko

| Risiko | Mitigasi |
|---|---|
| Asset lama tidak kompatibel | Audit format, node, animasi, polygon, texture |
| AR tidak tersedia atau adapter gagal | Fallback 3D |
| Pertanyaan tidak dikenali | Hint dan contoh prompt |
| Internet sekolah buruk | Offline-first |
| Asset terlalu berat | LOD, texture compression, batching |
| Jawaban esai salah dinilai AI | Review guru |


---

<!-- FILE: 02_FUNCTIONAL_REQUIREMENTS.md -->

# Functional Requirements

## Auth dan sesi

- FR-001 Guru/admin login dengan email.
- FR-002 Siswa dapat masuk memakai kode sesi.
- FR-003 Guru dapat membuat sesi pembelajaran.
- FR-004 Siswa dapat membuat atau bergabung ke kelompok.
- FR-005 Satu perangkat dapat mewakili satu kelompok.
- FR-006 Anggota kelompok dapat memakai akun atau nama manual.

## Device dan onboarding

- FR-010 Aplikasi memeriksa dukungan AR perangkat; pada Android pemeriksaan mencakup dukungan ARCore.
- FR-011 Jika tidak didukung, aplikasi menawarkan mode 3D.
- FR-012 Tutorial menjelaskan scan, placement, AI, logbook, dan reset.

## AR initialization

- FR-020 Kamera mendeteksi plane horizontal.
- FR-021 Pengguna mengonfirmasi posisi laboratorium.
- FR-022 Meja, Sampel A, dan Sampel B muncul.
- FR-023 Anchor harus stabil.
- FR-024 Tersedia reset scene.
- FR-025 Tracking loss tidak boleh menghapus jawaban atau progres.

## AI Assistant

- FR-030 Input teks wajib tersedia.
- FR-031 Input suara opsional.
- FR-032 Engine mengenali intent:
  - `inspect_sample_a_organel`
  - `inspect_sample_b_membrane`
  - `compare_outer_layers`
  - `request_hint`
  - `off_topic`
- FR-033 Pertanyaan ambigu tidak memicu event.
- FR-034 Respons fakta inti berasal dari konten tervalidasi.
- FR-035 Riwayat pertanyaan disimpan.

## Misi 1

- FR-040 Fokus ke Sampel A.
- FR-041 Smooth zoom ke internal sel.
- FR-042 Glow kuning pada kloroplas dan vakuola.
- FR-043 Jalankan animasi menyusut/mengempes.
- FR-044 Aktifkan form logbook Misi 1.

## Misi 2

- FR-050 Fokus ke Sampel B.
- FR-051 Zoom ke membran.
- FR-052 Tampilkan fosfolipid bilayer robek.
- FR-053 Jalankan particle system cairan.
- FR-054 Aktifkan form logbook Misi 2.

## Misi 3

- FR-060 Tampilkan kedua sampel berdampingan.
- FR-061 Highlight dinding sel.
- FR-062 Tampilkan tanda silang pada Sampel B.
- FR-063 Tampilkan panah gaya.
- FR-064 Aktifkan form logbook Misi 3.

## Logbook

- FR-070 Identitas kelompok.
- FR-071 Bentuk/gejala klinis tiap sampel.
- FR-072 Organel yang rusak.
- FR-073 Warna dan efek AR.
- FR-074 Bahan lapisan terluar.
- FR-075 Kondisi lapisan terluar.
- FR-076 Fungsi dan dampak kerusakan.
- FR-077 Autosave lokal.
- FR-078 Sinkronisasi ketika online.
- FR-079 Submission dapat dikunci dan dibuka kembali oleh guru.

## Kesimpulan

- FR-080 Identifikasi Sampel A dan alasan.
- FR-081 Identifikasi Sampel B dan alasan.
- FR-082 Hipotesis kelompok.
- FR-083 Validasi field wajib sebelum submit.

## Evaluasi POS

- FR-090 Guru memulai fase POS.
- FR-091 Sistem mendukung tiga marker.
- FR-092 PIN/manual fallback jika marker gagal.
- FR-093 Timer default 300 detik.
- FR-094 Autosave selama timer berjalan.
- FR-095 Rotasi kelompok.
- FR-096 Jawaban terkunci saat submit/waktu habis.

## Dashboard guru

- FR-100 Daftar kelompok.
- FR-101 Progress misi.
- FR-102 Pertanyaan ke AI.
- FR-103 Logbook.
- FR-104 Jawaban POS.
- FR-105 Penilaian dan feedback.
- FR-106 Export CSV.

## Admin

- FR-110 Kelola content version.
- FR-111 Kelola intent rules.
- FR-112 Kelola respons AI.
- FR-113 Kelola event sequence.
- FR-114 Kelola pertanyaan/rubrik.
- FR-115 Kelola metadata asset.


## Requirement khusus Flutter

- FR-120 Seluruh fitur UI, session, logbook, POS, dan dashboard menggunakan Flutter/Dart.
- FR-121 Akses AR harus melalui interface Dart agar plugin atau native bridge dapat diganti.
- FR-122 Platform Channel hanya digunakan untuk kemampuan AR native yang tidak tersedia atau tidak stabil di plugin Flutter.
- FR-123 Event AR mengirim state kembali ke Flutter: preparing, running, completed, failed, dan tracking_lost.
- FR-124 Flutter harus menyediakan fallback scene 3D non-AR tanpa mengubah flow misi.
- FR-125 Flutter Web menggunakan model data, validation rules, dan design tokens yang konsisten dengan aplikasi mobile.


---

<!-- FILE: 03_NON_FUNCTIONAL_REQUIREMENTS.md -->

# Non-Functional Requirements

## Performance
- Target minimal 30 FPS.
- Asset lokal tampil maksimal 5 detik setelah placement.
- Particle count adaptif.
- Texture mayoritas 1K, maksimal 2K untuk asset penting.
- Audit triangle count dan draw call untuk seluruh 30 asset.

## Reliability
- Tidak crash saat tracking hilang.
- Event AR tidak boleh berjalan ganda.
- Jawaban disimpan sebelum aplikasi masuk background.
- Submission memakai idempotency key.

## Offline
- Misi, logbook, dan POS dapat berjalan tanpa koneksi setelah content pack tersedia.
- Data disimpan pada database lokal SQLite-backed di Flutter.
- Sinkronisasi menggunakan retry.

## Security
- Supabase RLS wajib.
- Siswa hanya mengakses kelompoknya.
- Guru hanya mengakses kelas/sesinya.
- Service role key tidak boleh ada di aplikasi.
- Skor final tidak dapat diubah dari client siswa.

## Privacy
- Kamera tidak direkam.
- Audio hanya aktif saat tombol mic ditekan.
- Tidak mengunggah video kelas.
- Data siswa diminimalkan.

## Accessibility
- Semua informasi visual memiliki label teks.
- Warna bukan satu-satunya indikator.
- Ada reduce motion.
- Input teks selalu tersedia.

## Maintainability
- Event AR config-driven.
- Konten pendidikan terpisah dari kode.
- Asset mempunyai version dan checksum.
- Unit test untuk matcher, scoring, sync, dan completion guard.


## Flutter-specific

- Widget UI tidak boleh menyimpan business state permanen.
- AR renderer ditempatkan di belakang interface, bukan dipanggil langsung dari feature screen.
- Method Channel/Event Channel wajib memiliki timeout, error mapping, dan lifecycle handling.
- Native view tidak boleh menyebabkan memory leak saat route Flutter ditutup.
- Rebuild Flutter tidak boleh me-reset anchor atau event AR tanpa perintah domain.
- Dashboard Flutter Web harus diuji untuk Chrome versi sekolah yang digunakan.


---

<!-- FILE: 04_USER_FLOW_GAMEPLAY.md -->

# User Flow dan Gameplay

## Guru

```text
Login
→ Pilih kelas
→ Buat sesi
→ Atur durasi POS
→ Generate kode sesi
→ Mulai sesi
→ Pantau kelompok
→ Mulai fase POS
→ Review hasil
```

## Siswa

```text
Buka aplikasi
→ Device check
→ Masukkan kode sesi
→ Buat/gabung kelompok
→ Tutorial
→ Scan meja
→ Place laboratorium
→ Misi 1
→ Misi 2
→ Misi 3
→ Lengkapi logbook
→ Identifikasi sampel
→ Hipotesis
→ Submit investigasi
→ POS 1–3
→ Hasil sementara
```

## Interaction loop

```text
Amati
→ Tanya AI
→ Intent matcher
→ Event AR
→ Respons dan pertanyaan analisis
→ Isi logbook
→ Misi selesai
```

Jika tidak cocok:

```text
Tidak ada event
→ Hint
→ Contoh pertanyaan
→ Coba ulang
```

## State group

```text
joined
→ onboarding
→ ar_initializing
→ investigating
→ investigation_submitted
→ station_waiting
→ station_active
→ evaluation_submitted
→ reviewed
→ completed
```

## Error flow

### Tracking hilang
- Pause event.
- Minta arahkan kamera ke meja.
- Reset atau fallback setelah timeout.

### Offline
- Gameplay tetap berjalan.
- Tampilkan indikator offline.
- Queue data.

### Marker gagal
- Tampilkan panduan scan.
- Gunakan PIN POS.


---

<!-- FILE: 05_SYSTEM_ARCHITECTURE_FLUTTER.md -->

# System Architecture — Flutter

## 1. Arsitektur tingkat tinggi

```text
┌──────────────────────────────────────────────┐
│ Flutter Mobile App                           │
│                                              │
│ UI / Routing / State                         │
│ Domain Use Cases                             │
│ Local Database + Sync Queue                  │
│ AI Intent Engine                             │
│ AR Scene Adapter                             │
└───────────────────────┬──────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          │                           │
┌─────────▼─────────┐       ┌─────────▼─────────┐
│ Flutter AR Plugin │       │ Native AR Bridge  │
│ jika lolos spike │       │ Android ARCore    │
└─────────┬─────────┘       └─────────┬─────────┘
          └─────────────┬─────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│ Supabase                                      │
│ Auth | PostgreSQL | Storage | Edge Functions │
└───────────────────────┬──────────────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│ Flutter Web Dashboard                        │
└──────────────────────────────────────────────┘
```

## 2. Stack utama

- Flutter stable channel.
- Dart dengan null safety.
- Flutter Mobile untuk aplikasi siswa.
- Flutter Web untuk guru/admin.
- Supabase Flutter SDK untuk auth dan data.
- Database lokal SQLite-backed untuk offline-first.
- Background synchronization service.
- Secure storage untuk session/token.
- GLB/GLTF sebagai format asset utama.
- Platform Channel sebagai fallback integrasi AR native.

Nama package spesifik diputuskan setelah spike agar dokumentasi tidak mengunci proyek pada plugin yang belum terbukti memenuhi kebutuhan.

## 3. Struktur aplikasi

```text
lib/
  app/
    bootstrap/
    router/
    theme/
    config/
  core/
    auth/
    database/
    network/
    sync/
    errors/
    analytics/
    design_system/
  domain/
    entities/
    repositories/
    usecases/
  features/
    onboarding/
    learning_session/
    group/
    investigation/
    ai_assistant/
    logbook/
    conclusion/
    evaluation_stations/
    result/
  ar/
    contracts/
    controller/
    models/
    plugin_adapter/
    native_bridge/
    sequence_engine/
    asset_registry/
```

## 4. Layering

### Presentation
- Flutter screens dan widgets.
- Menampilkan state.
- Mengirim user intent ke controller/view model.
- Tidak memanggil Supabase atau AR native secara langsung.

### Application/Domain
- Use case seperti `JoinSession`, `StartMission`, `AskAssistant`, `SaveObservation`, `SubmitInvestigation`, dan `StartStation`.
- Completion guard dan scoring rules.
- Tidak bergantung pada widget atau platform.

### Data
- Repository implementation.
- Supabase data source.
- Local database.
- Sync queue.
- Asset manifest.

### AR
- Scene abstraction.
- Event sequence engine.
- Mapping asset code ke node.
- Plugin adapter/native bridge.
- Tracking dan lifecycle.

## 5. Kontrak AR Dart

```dart
abstract interface class ArSceneEngine {
  Stream<ArSceneState> get states;

  Future<void> initialize();
  Future<void> placeLaboratory(ArPlacement placement);
  Future<ArSequenceResult> runSequence(ArSequence sequence);
  Future<void> pause();
  Future<void> resume();
  Future<void> reset();
  Future<void> dispose();
}
```

Implementasi:

```text
FlutterPluginArSceneEngine
NativeAndroidArSceneEngine
FallbackThreeDimensionalSceneEngine
```

Feature misi hanya mengenal `ArSceneEngine`.

## 6. AR state machine

```text
uninitialized
→ scanning
→ planeDetected
→ placed
→ ready
→ sequencePreparing
→ sequenceRunning
→ sequenceCompleted
```

Error/interrupt:

```text
trackingLost
assetMissing
unsupportedDevice
nativeChannelError
cancelled
```

Ketika tracking hilang:
- Sequence dipause.
- Flutter menampilkan instruksi relocalization.
- Sequence dilanjutkan bila anchor pulih.
- Reset/fallback ditawarkan setelah timeout.

## 7. Config-driven sequence

```json
{
  "code": "zoom_chloroplast_vacuole",
  "steps": [
    {"type": "focus", "target": "SAMPLE_A"},
    {"type": "setOpacity", "target": "A_CELL_WALL", "value": 0.35},
    {"type": "zoom", "target": "A_CHLOROPLAST"},
    {"type": "glow", "targets": ["A_CHLOROPLAST", "A_VACUOLE"], "color": "#FFD500"},
    {"type": "playAnimation", "target": "A_CHLOROPLAST", "clip": "shrink"},
    {"type": "playAnimation", "target": "A_VACUOLE", "clip": "deflate"},
    {"type": "showPrompt", "code": "mission_1_analysis"}
  ]
}
```

Config misi dipaketkan secara lokal untuk MVP. Supabase mengirim content version dan event code yang diizinkan.

## 8. Intent engine

MVP menggunakan matcher deterministik di Dart:

```text
normalize
→ synonym map
→ required groups
→ excluded words
→ mission context
→ confidence
```

Output:

```dart
class IntentMatch {
  final String intentCode;
  final double confidence;
  final String? arSequenceCode;
}
```

AI generatif opsional hanya memberi penjelasan tambahan. Event AR tetap dipilih dari whitelist.

## 9. Offline-first

Database lokal menyimpan:
- Session snapshot.
- Kelompok dan anggota.
- Content version.
- Mission progress.
- Pertanyaan.
- Observation records.
- Kesimpulan.
- Station assignments.
- Station answers.
- Pending sync operations.

Setiap operasi mempunyai:
- UUID.
- Idempotency key.
- Entity version.
- Retry count.
- Last error.
- Created timestamp.

## 10. Flutter Web dashboard

Dashboard memakai:
- Auth dan role guard.
- Session overview.
- Tabel kelompok.
- Review jawaban.
- Scoring.
- CSV export.
- Content administration secara bertahap.

Flutter Web tidak menjalankan gameplay AR.

## 11. Deployment

### Android
- APK untuk pilot.
- App Bundle untuk distribusi.
- Environment dev, staging, production.

### Web
- Flutter Web static build.
- Hosting dengan HTTPS.
- Environment configuration terpisah.

### Supabase
- Staging dan production project.
- Migration versioned.
- RLS test.
- Seed content.

## 12. Risiko dan mitigasi

| Risiko | Mitigasi |
|---|---|
| Plugin AR Flutter tidak lengkap | Native ARCore bridge |
| Platform view lifecycle bermasalah | Spike dan lifecycle tests |
| 30 asset terlalu berat | Audit, LOD, texture compression |
| State Flutter dan native tidak sinkron | Event Channel + sequence ID |
| Offline conflict | Versioned upsert dan review |
| Flutter Web lambat pada tabel besar | Pagination/virtualization |


---

<!-- FILE: 06_FLUTTER_AR_IMPLEMENTATION_NOTES.md -->

# Flutter AR Implementation Notes

## 1. Keputusan implementasi

Flutter tetap menjadi application shell dan pemilik:
- Navigation.
- Session.
- Kelompok.
- AI intent.
- Logbook.
- Evaluation.
- Sync.
- Dashboard.

AR renderer dipilih melalui spike.

## 2. Strategi A — Flutter AR plugin

Gunakan bila plugin dapat membuktikan:
- Horizontal plane detection.
- Stable anchor.
- GLB/GLTF loading.
- Animation clip control.
- Material opacity.
- Glow/highlight.
- Particle system.
- Image/marker tracking.
- Camera transition.
- Tracking recovery.
- Event callback ke Dart.
- Minimal 30 FPS pada perangkat target.

## 3. Strategi B — Native Android AR bridge

Gunakan bila satu atau lebih kemampuan kritis tidak stabil.

Flutter mengirim command:

```json
{
  "command": "runSequence",
  "sequenceId": "uuid",
  "sequenceCode": "zoom_membrane_particle",
  "config": {}
}
```

Native mengirim event:

```json
{
  "sequenceId": "uuid",
  "state": "running",
  "stepIndex": 3,
  "tracking": "normal"
}
```

Final:

```json
{
  "sequenceId": "uuid",
  "state": "completed"
}
```

## 4. Platform Channel

Channel minimum:
- `cell_forensic/ar_commands`
- `cell_forensic/ar_events`
- `cell_forensic/ar_capabilities`

Command:
- initialize
- detectCapability
- placeLaboratory
- runSequence
- pauseSequence
- resumeSequence
- reset
- dispose
- scanStationMarker

Event:
- initialized
- planeDetected
- placed
- trackingChanged
- sequenceStarted
- sequenceStepChanged
- sequenceCompleted
- markerDetected
- error

## 5. Asset registry

Contoh:

```dart
class ArAssetDefinition {
  final String code;
  final String path;
  final String rootNode;
  final Map<String, String> nodes;
  final Map<String, String> animations;
  final String checksum;
}
```

Registry membaca manifest hasil audit 30 asset.

## 6. Scene separation

Scene:
- `investigation_lab`
- `mission_1_internal`
- `mission_2_membrane`
- `mission_3_comparison`
- `station_1`
- `station_2`
- `station_3`
- `fallback_3d`

Tidak semua asset harus aktif bersamaan.

## 7. Memory management

- Preload hanya asset misi aktif dan berikutnya.
- Dispose texture/material yang tidak dipakai.
- Particle emitter dihentikan setelah sequence.
- Platform view dihancurkan saat sesi selesai.
- Cache asset mengikuti content version.
- Monitor memory sebelum dan setelah setiap misi.

## 8. Flutter lifecycle

- `inactive`: pause camera/renderer.
- `paused`: simpan state dan hentikan rendering berat.
- `resumed`: validasi session native dan relocalize.
- `detached`: dispose channel dan renderer.

## 9. Testing

### Dart
- Intent matcher.
- Sequence parser.
- Completion guard.
- Sync queue.
- Scoring.

### Integration
- Flutter command menghasilkan native event.
- Sequence ID tidak tertukar.
- Route keluar menghentikan renderer.
- Background/foreground mempertahankan jawaban.
- Tracking lost tidak menggandakan event.

### Device
- 30 asset.
- 3 tier perangkat.
- Marker.
- Low light.
- Thermal.
- Memory.
- FPS.

## 10. Fallback 3D

Fallback menggunakan scene 3D tanpa camera passthrough:
- Drag untuk rotasi.
- Pinch untuk zoom.
- Tap hotspot.
- Menjalankan sequence yang sama.
- Misi dan logbook identik.


---

<!-- FILE: 07_DATABASE_SCHEMA.md -->

# Database Schema

## Organisasi

### profiles
- id
- full_name
- role
- active_school_id

### schools
- id
- name
- code

### classes
- id
- school_id
- name
- grade_level

### class_members
- class_id
- profile_id
- member_role

## Konten

### content_versions
- id
- version_code
- status
- published_at

### missions
- id
- content_version_id
- code
- title
- order_number
- sample_ref

### intent_rules
- id
- mission_id
- intent_code
- rule_config jsonb
- ar_sequence_code
- response_code

### ar_sequences
- id
- code
- version
- config jsonb

### assets
- id
- asset_code
- file_path
- checksum
- metadata jsonb

## Sesi dan kelompok

### learning_sessions
- id
- class_id
- teacher_id
- content_version_id
- join_code
- status
- station_duration_seconds

### groups
- id
- session_id
- name
- leader_profile_id
- device_installation_id

### group_members
- id
- group_id
- profile_id nullable
- display_name
- is_leader

## Investigasi

### mission_progress
- id
- group_id
- mission_id
- status
- ar_mode
- started_at
- completed_at

### student_questions
- id
- group_id
- mission_id
- question_text
- matched_intent
- confidence
- ar_sequence_code

### observation_records
- id
- group_id
- mission_id
- sample_ref
- detected_structure
- structure_state
- glow_color
- visual_effects
- outer_layer_material
- outer_layer_condition
- function_analysis
- damage_impact
- version

### investigation_conclusions
- id
- group_id
- sample_a_identity
- sample_a_reasoning
- sample_b_identity
- sample_b_reasoning
- group_hypothesis
- status

## POS

### evaluation_stations
- id
- code
- title
- marker_code
- asset_code

### questions
- id
- station_id
- code
- question_text
- question_type
- correct_answer
- rubric
- max_score

### station_assignments
- id
- session_id
- group_id
- station_id
- rotation_number
- status

### station_attempts
- id
- assignment_id
- started_at
- expires_at
- submitted_at
- status

### answers
- id
- group_id
- question_id
- station_attempt_id
- answer_text
- auto_score
- teacher_score
- final_score
- feedback
- version

## RLS

- Anggota hanya membaca/menulis group sendiri.
- Guru hanya mengakses sesi kelasnya.
- Admin mengelola konten.
- Published content dapat dibaca peserta sesi.


---

<!-- FILE: 08_API_CONTRACT.md -->

# API Contract

Base:
`/functions/v1`

## Join session

```http
POST /join-session
```

```json
{
  "join_code": "CF-82KD",
  "display_name": "Riko",
  "installation_id": "uuid"
}
```

## Create group

```http
POST /groups
```

```json
{
  "session_id": "uuid",
  "name": "Kelompok 1",
  "members": [
    {"display_name": "Riko"},
    {"display_name": "Ayu"}
  ]
}
```

## Content pack

```http
GET /content-pack?session_id=uuid
```

Mengembalikan:
- missions
- intent_rules
- responses
- ar_sequences
- stations
- questions
- asset manifest

## Ask assistant

```http
POST /assistant/ask
```

```json
{
  "session_id": "uuid",
  "group_id": "uuid",
  "mission_code": "mission_1",
  "question_text": "Periksa organel Sampel A",
  "input_mode": "text"
}
```

Response:
```json
{
  "intent": "inspect_sample_a_organel",
  "confidence": 0.97,
  "response_text": "Hasil pemindaian menunjukkan...",
  "analysis_prompt": "Apa dampaknya...",
  "ar_sequence_code": "zoom_chloroplast_vacuole"
}
```

## Observation

```http
PUT /observations/{id}
```

## Complete mission

```http
POST /missions/complete
```

## Submit investigation

```http
POST /investigation/submit
```

## Start station

```http
POST /stations/start
```

## Save answer

```http
PUT /stations/attempts/{attemptId}/answers/{questionId}
```

## Submit station

```http
POST /stations/attempts/{attemptId}/submit
```

## Teacher overview

```http
GET /teacher/sessions/{sessionId}/overview
```

## Review answer

```http
POST /teacher/answers/{answerId}/review
```


---

<!-- FILE: 09_LKPD_EVALUATION_SCORING.md -->

# LKPD dan Scoring

## Form identitas
- Nama kelompok.
- Sekolah.
- Kelas.
- Anggota.
- Guru.
- Sesi.

## Pengamatan internal

Per sampel:
- Bentuk/gejala.
- Struktur yang diamati.
- Kondisi.
- Glow.
- Efek.
- Fungsi.
- Dampak kerusakan.

## Lapisan terluar

Per sampel:
- Nama lapisan.
- Bahan penyusun.
- Kondisi.
- Fungsi.
- Dampak.

## Kesimpulan

### Sampel A
- Identitas.
- Alasan berdasarkan dinding sel.
- Alasan berdasarkan organel.

### Sampel B
- Identitas.
- Alasan berdasarkan bentuk dan lapisan.

### Hipotesis
Satu paragraf berbasis bukti.

## Bobot rekomendasi

| Komponen | Bobot |
|---|---:|
| Data laboratorium | 25 |
| Identifikasi sampel | 15 |
| Hipotesis | 10 |
| POS 1 | 15 |
| POS 2 | 20 |
| POS 3 | 15 |
| Total | 100 |

## Catatan kunci

- Organel X/Y belum boleh ditetapkan sebelum asset final dikonfirmasi.
- Bagian nomor 1/2 pada membran belum boleh ditetapkan sebelum diagram final dikonfirmasi.
- Esai harus dapat direview guru.
- AI hanya memberikan skor saran.


---

<!-- FILE: 10_ASSET_INVENTORY_AUDIT.md -->

# Asset Inventory dan Audit

## Status

Tersedia sekitar **30 asset 3D**. Berdasarkan screenshot, 10 asset yang sudah terkonfirmasi:

1. `forensic_lab_table`
2. `plant_cell_sample_a`
3. `animal_cell_sample_b`
4. `cell_wall_layer`
5. `chloroplast_intact`
6. `chloroplast_shrinking`
7. `giant_vacuole_intact`
8. `giant_vacuole_collapsed`
9. `phospholipid_bilayer_intact`
10. `phospholipid_bilayer_torn`

Sekitar 20 asset lain masih harus dimasukkan ke inventory berdasarkan file sebenarnya.

## Dampak ke scope

Karena asset sudah tersedia:
- Tidak perlu mulai modeling dari nol.
- Phase asset berubah menjadi audit, optimasi, dan integrasi.
- Timeline dapat berkurang jika seluruh asset kompatibel.
- Risiko utama berpindah ke format, naming, node, animation, dan performa.

## Data inventory wajib

| Field | Keterangan |
|---|---|
| asset_code | Nama stabil |
| filename | Nama file |
| format | GLB/GLTF/FBX/OBJ |
| size_bytes | Ukuran |
| triangle_count | Polygon |
| texture_count | Jumlah texture |
| max_texture | Resolusi terbesar |
| material_count | Material |
| animation_clips | Daftar clip |
| node_names | Node penting |
| pivot_ok | Ya/tidak |
| scale_ok | Ya/tidak |
| alpha_used | Ya/tidak |
| renderer_test | Flutter plugin/native bridge/fallback 3D |
| fps_result | Hasil benchmark |
| status | ready/fix/rebuild |

## Acceptance

Asset dinyatakan siap jika:
- Bisa dimuat tanpa texture hilang.
- Pivot dan scale benar.
- Node target stabil.
- Animasi dapat dipanggil dari kode.
- Material transparan bekerja.
- Glow dapat diterapkan.
- Particle origin tersedia.
- FPS memenuhi target.
- Tidak ada hak lisensi yang bermasalah.

## Node map minimum

```text
ROOT_LAB
SAMPLE_A
A_CELL_WALL
A_CHLOROPLAST
A_VACUOLE
SAMPLE_B
B_MEMBRANE
B_BILAYER
B_LEAK_ORIGIN
```

## Audit batch

### Batch 1 — Scene
- forensic_lab_table
- plant_cell_sample_a
- animal_cell_sample_b

### Batch 2 — Misi 1
- cell_wall_layer
- chloroplast_intact
- chloroplast_shrinking
- giant_vacuole_intact
- giant_vacuole_collapsed

### Batch 3 — Misi 2
- phospholipid_bilayer_intact
- phospholipid_bilayer_torn
- asset particle/leak yang belum terdaftar

### Batch 4 — Misi 3 dan POS
- highlight/force indicators
- organel X/Y
- membran bernomor
- marker POS
- asset pendukung lainnya

## Keputusan setelah audit

- `READY`: langsung integrasi.
- `FIX`: optimasi texture/polygon/node.
- `REBUILD`: format atau struktur tidak layak.


## Integrasi Flutter

Setiap asset harus diuji melalui `ArAssetDefinition` dan manifest, bukan dipanggil menggunakan path hard-code dari screen.

Field tambahan:
- `flutter_asset_path`
- `native_asset_path`
- `supported_renderer`
- `preload_group`
- `dispose_group`
- `fallback_thumbnail`
- `node_mapping_valid`
- `animation_mapping_valid`


---

<!-- FILE: 11_MVP_ROADMAP.md -->

# MVP Roadmap — Flutter

## Phase 0 — Audit asset dan Flutter AR spike
Durasi: 1–2 minggu.

- Inventory seluruh 30 asset.
- Audit format, texture, polygon, pivot, node, dan animation.
- Flutter project spike.
- Uji plugin AR.
- Uji native ARCore bridge jika plugin gagal.
- Plane detection.
- Load Sampel A/B.
- Glow.
- Transparency.
- Particle.
- Marker POS.
- Benchmark tiga kelas perangkat.
- Tetapkan renderer final.

## Phase 1 — Flutter foundation
Durasi: 1 minggu.

- Flutter mobile dan Flutter web workspace.
- Routing.
- Theme/design system.
- Supabase.
- Database lokal.
- Offline sync queue.
- Environment dan CI.

## Phase 2 — Session dan kelompok
Durasi: 1 minggu.

- Join code.
- Group.
- Member.
- Session snapshot.
- Dashboard create session.

## Phase 3 — Scene dan tiga misi
Durasi: 2–3 minggu.

- Scan dan placement.
- Scene adapter.
- Sequence engine.
- Misi 1–3.
- Tracking recovery.
- Fallback 3D.

## Phase 4 — AI intent dan logbook
Durasi: 1–2 minggu.

- Chat Flutter.
- Intent matcher Dart.
- Controlled responses.
- Observation form.
- Autosave.
- Conclusion dan hypothesis.

## Phase 5 — POS
Durasi: 1–2 minggu.

- Marker/PIN.
- Timer.
- Rotation.
- POS 1–3.
- Submission.

## Phase 6 — Flutter Web dashboard
Durasi: 1–2 minggu.

- Session overview.
- Group detail.
- Review.
- Scoring.
- CSV export.

## Phase 7 — QA dan pilot
Durasi: 1–2 minggu.

- RLS.
- Device matrix.
- Performance.
- Classroom simulation.
- APK/AAB.
- Flutter Web deployment.

## Estimasi

Jika asset lolos audit dan plugin AR memenuhi kebutuhan:
- Sekitar 8–11 minggu.

Jika memerlukan native Android AR bridge:
- Sekitar 10–14 minggu.

Jika asset perlu banyak perbaikan:
- Tambahkan 2–4 minggu.

## MVP wajib

- Flutter Android.
- Flutter Web dashboard.
- Tiga misi.
- LKPD lengkap.
- POS 1–3.
- Offline-first.
- Fallback 3D.
- Supabase dan RLS.


---

<!-- FILE: 12_ADR_STACK_DECISION.md -->

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

Akses AR ditempatkan di belakang `ArSceneEngine`.

Urutan keputusan:
1. Uji plugin Flutter melalui spike.
2. Jika seluruh kebutuhan kritis lulus, gunakan plugin.
3. Jika tidak, pertahankan Flutter sebagai application shell dan implementasikan renderer Android ARCore melalui Platform Channel.
4. Sediakan fallback 3D untuk perangkat tanpa AR.

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
