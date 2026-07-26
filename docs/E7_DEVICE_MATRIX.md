# E7-03 — Device Matrix & Acceptance Checklist

Tanggal: 2026-07-26  
Project: Cell Forensic

## Tiers

| Tier | Meaning | CI? |
|---|---|---|
| **A** | Must pass before classroom pilot | Manual / local devices only |
| **B** | Should pass; document workarounds | Manual |
| **C** | Nice-to-have / known-limited | Manual; failures OK if fallback works |

GitHub Actions (`ubuntu-latest`) has **no** ARCore, camera, or student tablets — matrix rows below are **not** runnable in CI. CI covers `dart analyze`, `flutter test`, and `flutter build web` (dashboard).

## Matrix

| Device / class | OS | ARCore | Tier | AR path | Fallback 3D | Join `CELL01` | Stations | Notes |
|---|---|---|---|---|---|---|---|---|
| Pixel 6 / 7 / 8 class | Android 13–15 | Yes | A | Live plugin | Pass | Pass | Pass | Primary spike device (E0) |
| Samsung A-series (A34/A54) | Android 13–14 | Yes | A | Live | Pass | Pass | Pass | Common school devices |
| Mid-range ARCore phone (Snapdragon 7-gen) | Android 12+ | Yes | A | Live | Pass | Pass | Pass | minSdk 28 |
| Low-RAM (≤4 GB) ARCore | Android 12+ | Yes | B | Live or thermal fallback | Pass | Pass | Pass | Watch AllInOne 287k tris FPS |
| Non-ARCore Android | Android 12+ | No | B | — | **Required** | Pass | Pass | Device check → Model Viewer |
| ChromeOS / Android tablet | varies | Partial | B | If ARCore | Pass | Pass | Pass | Large screen layout |
| iOS (any) | iOS | — | C | Out of MVP | — | — | — | Not in MVP release |
| Emulator (no Google Play) | — | No | C | — | Pass | Local only | Pass | No ARCore |
| Flutter Web student | Desktop browser | — | C | — | Limited | N/A | N/A | Student app is Android APK |

## Acceptance checklist (Tier A)

### Environment

- [ ] APK installed from `scripts/release_android.sh` (or equivalent)
- [ ] Supabase URL + anon key embedded via `--dart-define` / flavor
- [ ] Demo session `CELL01` status = `active`
- [ ] Teacher dashboard open (`flutter build web -t lib/main_dashboard.dart`)

### Journey

- [ ] Onboarding + device check completes
- [ ] Join code `CELL01` resolves (remote or local fallback)
- [ ] Create group + leader + members (exactly one leader)
- [ ] Kill app → relaunch restores session snapshot

### AR / 3D

- [ ] Plane scan → place GLB (Tier A ARCore devices)
- [ ] Sequence step advances; tracking-lost overlay works
- [ ] App background/foreground does not skip steps (E7-02)
- [ ] Non-ARCore path uses Model Viewer without crash

### LKPD / sync

- [ ] Logbook autosave local; remote upsert when `remoteGroupId` set
- [ ] Conclusion submit visible on teacher dashboard (active session)

### Stations (owned by E5 — smoke only)

- [ ] POS access (PIN/marker) opens station
- [ ] Timer + answer autosave; submit appears for teacher review

### Security smoke

- [ ] Ended session (`status != active`) rejects new group create
- [ ] Anon cannot SELECT `profiles` rows

## Not in CI

- Physical ARCore plane detection / FPS / thermal
- Camera permission dialogs
- Multi-device classroom RF / Wi-Fi contention
- Real student tablet fleet diversity
- Play Store / internal-track upload
