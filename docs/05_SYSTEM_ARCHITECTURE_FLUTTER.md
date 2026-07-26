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
