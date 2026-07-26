# E11 — Live AR Upgrades + OpenAI-Compatible AI Integration

> **Naming note:** The user-facing label “E10 AR+AI” maps to epic **E11** in this repo.
> Epic **E10** is already reserved for security privilege hardening
> (`e10_security_harden_privileges`). Do not overwrite E10 security docs.

## Status

Implemented in Flutter (student app) + Supabase Edge Function proxy.
`dart analyze lib test` clean for E11 sources; full `flutter test` green (209 tests, 2026-07-26).

## Architecture

```
Student question
  → AssistantViewModel
      → provisional / explicit off-topic → IntentMatcher (local)
      → else Supabase Edge Function `ai-assistant` (proxy)
           → OPENAI_BASE_URL + OPENAI_MODEL + OPENAI_API_KEY (secrets only)
           → structured JSON {message, intent, mission, target, ar_action, confidence}
      → on failure → IntentMatcher (mission continues; AR state uncleared)
  → ArActionWhitelist.resolve
  → ArVisualDirector.applyAiAction
  → ArSceneEngine visual APIs
  → MissionScenePanel (same live ARView / same plane anchor)
```

Sequence path (unchanged mission flow):

```
Jalankan Langkah → SequenceEngine → ArSceneEngine.runAction
                 → ArVisualDirector.applySequenceStep (M1–M3 visuals)
                 → MissionScenePanel swaps GLB on the active ARPlaneAnchor
```

## Live AR flow (DoD)

1. Device check chooses AR (`arSupported: true`) → `LiveArSceneEngine`.
2. `MissionScenePanel` hosts `ARView` with a stable `GlobalKey` (no separate viewer page).
3. Plane detect → tap → place GLB on `ARPlaneAnchor`.
4. Sequence steps M1–M3 call `replaceModelAtActiveAnchor` / secondary node / overlays
   **on the same anchor**; placement coordinates are not cleared.
5. Tracking loss / lifecycle pause still gates `runAction` via `ArLifecycleController`.

## Fallback conditions (`model_viewer_plus`)

Fallback is **only** for:

| Condition | Behavior |
|---|---|
| User chose “Gunakan Mode 3D” at device check | `FakeArSceneEngine` + Model Viewer from the start |
| Fatal live AR init failure (`not supported` / `unavailable` / create failure) **before** successful place | Soft UI fallback banner + Model Viewer; sequence unchanged |
| Widget tests (`debugUsePlaceholderScene`) | Placeholder canvas (no platform views) |

Fallback must **not** activate when ARCore successfully initialized camera/session and the model is placed. Successful place clears any soft-fallback flag.

## M1–M3 visual upgrades

| Mission | Steps → visuals |
|---|---|
| M1 | focus Sample A → kloroplas solo + glow overlay → vacuole shrink overlay |
| M2 | focus membrane → torn bilayer (RantaiProtein) → water-leak CustomPainter drops |
| M3 | Sample A+B side-by-side on same tabletop anchor → cell wall highlight → missing-structure cross on B → force arrows |

Organel X/Y and membrane 1/2 remain provisional (never auto-scored; AI proxy + IntentMatcher both refuse invented facts).

## Gestures (E11-G)

- Perbesar / Perkecil (pinch-scale approximation)
- Putar
- Kembali ke posisi awal (`resetTransform`)
- Ketuk kloroplas / membran (structure select + highlight)
- Ketuk bidang lagi = reposisi (new anchor) — does not run on step change

Gestures do not advance sequence, clear autosave, or bypass tracking pause.

## AI actions (whitelist)

```
none, focus_sample_a, focus_sample_b, highlight_chloroplast,
show_damaged_chloroplast, show_vacuole_damage, focus_membrane,
show_membrane_damage, show_water_leak, compare_samples,
highlight_cell_wall, show_force_arrows, reset_scene
```

Rules (`ArActionWhitelist`):

- Unknown action → `none`
- Mission mismatch → `none` (message may still show)
- `confidence < 0.6` → `none`
- API / network failure → IntentMatcher; never stop mission; never clear AR state
- Logs use `developer.log` with error **type** only (no keys / raw bodies)

## Server config (secrets — set in Supabase Dashboard)

Edge Function: `supabase/functions/ai-assistant`

| Secret | Example / default | Where |
|---|---|---|
| `OPENAI_API_KEY` | *(required — never commit)* | Supabase → Project Settings → Edge Functions → Secrets |
| `OPENAI_BASE_URL` | `https://api.arklabs.biz.id/v1` | same |
| `OPENAI_MODEL` | `cell-forensik` | same |

Deploy:

```bash
supabase functions deploy ai-assistant
```

Flutter client calls `supabase.functions.invoke('ai-assistant', body: {message, mission})`
using only `SUPABASE_URL` + publishable/anon key. **Never** put `OPENAI_API_KEY` in
Flutter, APK, web bundle, repo, or `--dart-define`.

## Plugin limits (documented)

`ar_flutter_plugin_2` supports plane/anchor/GLB node add-remove and local transform
via `ARNode` (`scale` / `position` / `eulerAngles`). It does **not** expose:

- Native material glow / PBR highlight channels
- Particle emitters / animation clip playback on GLB

E11 approximates with GLB swap + Flutter `CustomPainter` overlays anchored to the
model frame. No native ARCore bridge was added (E0-05 remains deferred).

## Files changed (summary)

| Area | Paths |
|---|---|
| AR engine | `lib/ar/ar_scene_engine.dart`, `ar_visual_director.dart`, `ar_scene_overlays.dart`, `mission_scene_panel.dart` |
| AI domain | `lib/domain/ai/ar_action_whitelist.dart`, `ai_assistant_response.dart`, `ai_assistant_client.dart` |
| Assistant | `lib/ui/features/assistant/assistant_view_model.dart`, `assistant_view.dart` |
| Mission UI | `lib/features/journey/screens/investigation/mission_screen.dart` |
| Edge Function | `supabase/functions/ai-assistant/index.ts` |
| Tests | `test/ar/*`, `test/domain/ai/*`, `test/ui/features/assistant/assistant_ai_fallback_test.dart` |
| Docs | this file, `docs/TASK-REGISTRY.yaml` (E11), README pointer |

## Analyze / test results

```text
dart analyze lib test   # E11 sources clean (pre-existing unrelated infos elsewhere OK)
flutter test            # 209 passed (2026-07-26)
```

## Physical device notes

Not re-run in this change set (CI has no ARCore device). Facilitator checklist remains
in `docs/E7_DEVICE_MATRIX.md`:

- [ ] ARCore device: camera stays open through M1–M3; model stays on tabletop anchor
- [ ] Sequence is not a separate 3D viewer page
- [ ] Soft fallback only on unsupported / init failure
- [ ] AI proxy with secrets configured; offline IntentMatcher still answers

## Security coordination

E10 privilege hardening is unchanged. This epic does not widen RLS, expose
`service_role`, or embed model API keys in clients.
