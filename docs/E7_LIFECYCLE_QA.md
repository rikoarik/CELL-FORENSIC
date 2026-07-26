# E7-02 — Flutter Lifecycle & Native Channel QA

Tanggal: 2026-07-26  
Project: Cell Forensic

## Scope

Document and harness app lifecycle → AR sequence pause/resume. Native AR channel behavior cannot be fully exercised in CI (no ARCore / camera on GitHub runners).

## App lifecycle contract

| `AppLifecycleState` | Expected AR / sequence behavior |
|---|---|
| `inactive` | Pause sequence (`ArTrackingState.lost`) |
| `paused` | Same as inactive (home button / app switcher) |
| `hidden` | Same (multi-window / iOS-style hide) |
| `resumed` | Restore tracking **only if** lifecycle controller paused it |
| `detached` | No-op (engine disposed with widget) |

Genuine ARCore tracking loss (via `ARSessionManager.onError`) must **not** be auto-cleared on resume — student must recover by moving the device (existing E3-07 overlay).

## Implementation

| Piece | Path |
|---|---|
| Controller | `lib/ar/ar_lifecycle_controller.dart` |
| Wiring | `MissionScenePanel` + `WidgetsBindingObserver` |
| Unit tests | `test/ar/ar_lifecycle_controller_test.dart` |
| Engine pause semantics | `test/ar/ar_scene_engine_test.dart` (already covers lost→resume action queue) |

## Native channel notes (`ar_flutter_plugin_2`)

| Channel / callback | Lifecycle note | CI |
|---|---|---|
| `ARView` platform view | Destroyed/recreated with widget; call `ARSessionManager.dispose()` in `State.dispose` | Not runnable |
| `onPlaneOrPointTap` | Ignore while `sequencePaused` / lifecycle pause | Manual device |
| `onPlaneDetected` | May fire during init — handlers assigned before `onInitialize` | Manual |
| `onError` (tracking/relocalize) | Maps to `updateTracking(lost)` | Manual |
| `addAnchor` / `addNode` | File GLB via `GlbAssetLoader.ensureOnDisk` | Manual |
| Model Viewer fallback | No native AR session; lifecycle still pauses `ArSceneEngine` | Partial (widget tests use placeholder) |

## Manual device checklist (not CI)

- [ ] Mid-mission: press Home → overlay / sequence paused → resume app → can continue step
- [ ] Incoming call / notification shade (`inactive`) does not advance sequence
- [ ] After OS kill, journey restores from `SessionSnapshotStore` (E2-04) — AR placement reset expected
- [ ] Tracking-lost overlay still appears when waving device away from plane (independent of lifecycle)
- [ ] Fallback 3D path: lifecycle pause still blocks `runAction` completion until resume

## What CI covers

```bash
flutter test test/ar/ar_lifecycle_controller_test.dart test/ar/ar_scene_engine_test.dart
dart analyze
```

CI does **not** cover: ARCore session suspend, camera permission revoke, thermal throttle, or physical plane relocalization.
