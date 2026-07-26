# E3 — AR Investigation

Tanggal: 2026-07-26  
Project: Cell Forensic

## Ringkasan

Investigasi AR/3D berjalan end-to-end di `MissionScreen` + `MissionScenePanel` dengan `SequenceEngine` dan `ArSceneEngine` (Fake/Live) yang sama untuk ketiga misi.

| Task | Status | Catatan |
|---|---|---|
| E3-01 Surface scan & placement | done | Plane scan hint → tap place; reset scene |
| E3-02 ArSceneEngine | done | `LiveArSceneEngine` + `FakeArSceneEngine` via `ControllableArSceneEngine` |
| E3-03 Sequence engine | done | Wired ke scene; step swap model via `ArAssetRegistry` |
| E3-04 Mission 1 | done | SEQ-MISI-1 + logbook + intent |
| E3-05 Mission 2 | done | SEQ-MISI-2 + logbook + intent |
| E3-06 Mission 3 | done | SEQ-MISI-3 + logbook + intent |
| E3-07 Tracking recovery | done | Pause sequence saat lost; resume; overlay UI |
| E3-08 Fallback 3D | done | `model_viewer_plus`, parity sequence penuh |

## Alur scene

```text
arSupported == true
  scanning → planeReady → placed → sequence steps (model swap)
  tracking lost → pause UI + engine.isPaused → recover → resume
else
  FakeArSceneEngine auto-place → ModelViewer + sequence sama
```

## File kunci

- `lib/ar/mission_scene_panel.dart`
- `lib/ar/ar_scene_engine.dart`
- `lib/ar/ar_asset_registry.dart`
- `lib/domain/sequence_engine.dart`
- `lib/features/journey/screens/investigation/mission_screen.dart`

## Batasan MVP

- Tidak ada clip animasi native / particle emitter (E0 gap) — diganti model swap + camera orbit.
- Tracking lost dari plugin diinfer dari `onError` + kontrol debug di test placeholder.
- Device matrix FPS / thermal tetap E7.
