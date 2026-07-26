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

### Keputusan renderer (Phase 0 spike — accepted untuk MVP lokal)

| Jalur | Teknologi | Kapan dipakai |
|---|---|---|
| AR kamera | `ar_flutter_plugin_2` (ARCore + sceneview) | `StudentJourney.arSupported == true` |
| Fallback 3D | `model_viewer_plus` (GLB interaktif) | perangkat / pilihan Mode 3D |

Implementasi di kode:
- `lib/ar/mission_scene_panel.dart` — widget scene bersama (AR atau 3D).
- `lib/ar/ar_asset_registry.dart` — mapping misi → path GLB.
- `lib/ar/glb_asset_loader.dart` — salin asset ke documents untuk `fileSystemAppFolderGLB`.
- `MissionScreen` memilih jalur dari `journey.arSupported`; sequence + logbook identik.

Native Android bridge (Strategi B) ditunda sampai plugin gagal memenuhi capability kritis di device matrix.

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

Fallback memakai `model_viewer_plus` tanpa camera passthrough:
- Drag untuk rotasi.
- Pinch untuk zoom.
- Orbit kamera berubah per langkah sequence (`ArAssetRegistry.cameraOrbitForStep`).
- Menjalankan `SequenceEngine` yang sama dengan Mode AR.
- Misi dan logbook identik (FR-124).

Model utama per misi (MVP):
- MISI-1 → `SelTumbuhanRework_AllInOne.glb`, lalu solo Nukleus / Kloroplas / Vakuola per langkah
- MISI-2 → `SelHewanBroken.glb`, lalu `RantaiProtein.glb` pada langkah membran/kebocoran
- MISI-3 → AllInOne → `DindingSel_Solo` → Sampel B → Mitokondria (force arrows)

Mapping lengkap ada di `ArAssetRegistry.modelForStep`.

Catatan: file dengan `+` di nama (`All+Meja.glb`) sengaja tidak dipakai di viewer karena memecah URL asset WebView. Nested folder (`SelTumbuhhanSolo/`, `RantaiProtein/`) harus didaftarkan di `pubspec.yaml` (Flutter asset dir tidak rekursif).
