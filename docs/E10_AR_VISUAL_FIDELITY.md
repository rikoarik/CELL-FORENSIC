# E10 — AR Visual Fidelity

> **Naming note:** Epic **E10** in `TASK-REGISTRY.yaml` is security privilege hardening.
> This document tracks **AR visual/interaction fidelity** audits (user label “E10 AR”).
> Live AR + AI implementation details remain in `docs/E11_AR_AI_INTEGRATION.md`.

## Wave 1 — AR Audit

**Mode:** AUDIT ONLY (no production edits).  
**Source of truth:** `CELL FORENSIC (3).pdf` Scene 2 visual scripts (Misi 1–3).  
**Code under audit:** `mission_scene_panel.dart`, `ar_scene_engine.dart`, `ar_asset_registry.dart`, `ar_visual_director.dart`, `sequence_engine.dart`, `mission_screen.dart`.  
**Date:** 2026-07-26.

### PDF desired beats (verbatim intent)

| Misi | Trigger keywords | Desired AR output |
|---|---|---|
| **1** | Sampel A + Rusak/Organel | Smooth zoom-in through cell wall → yellow glow on shrinking chloroplast + deflating giant vacuole |
| **2** | Sampel B + Bocor/Cairan/Membran | Zoom to outer membrane → torn phospholipid bilayer → blue water particle spray |
| **3** | A tidak hancur / perbedaan / bentuk tetap | Side-by-side A+B → green cell-wall contour on A → red X on B → 3D force arrows |

### sequenceCode → AR action mapping

| Intent / content | sequenceCode | MissionSequences | Step codes → `ArVisualDirector.applySequenceStep` |
|---|---|---|---|
| Misi 1 | `SEQ-MISI-1` | `misi1` | `focus_sample_a` → `zoom_internal` → `glow_organelles` → `play_shrink_animation` |
| Misi 2 | `SEQ-MISI-2` | `misi2` | `focus_sample_b` → `zoom_membrane` → `show_torn_bilayer` → `play_leak_particles` |
| Misi 3 | `SEQ-MISI-3` | `misi3` | `show_both_samples` → `highlight_cell_wall` → `mark_sample_b` → `show_force_arrows` |

Offline path: `IntentMatcher.sequenceCode` → `MissionScreen._playSequenceFromCode` → `SequenceEngine.startForSequenceCode` → per-step `runAction` + `ArVisualDirector` (same lab-table anchor; no re-place).

### Gap matrix — Misi 1–3

Legend (primary realization of the beat):

- **live tabletop AR** — change on the placed `ARPlaneAnchor` / lab scene (may include overlay)
- **model swap** — primary GLB replace via `replaceModelAtActiveAnchor` / registry step model
- **camera orbit** — `ModelViewer.cameraOrbit` only (fallback 3D); no true AR camera dolly
- **missing** — PDF effect absent or only a non-equivalent stub

| Misi | Step code | PDF beat | Classification | Evidence / gap |
|---|---|---|---|---|
| 1 | `focus_sample_a` | Focus Sampel A | **live tabletop AR** | Clear secondary, highlight Sample A; primary stays `sampleA` AllInOne. No re-anchor. |
| 1 | `zoom_internal` | Smooth zoom through cell wall | **camera orbit** (fallback) / approx live | Fallback: `cameraOrbitForStep` → `0deg 65deg 1.4m`. Live: `setNodeScale(primary, 1.2)` + overlay — **no** AR camera zoom API. True smooth zoom **missing** on live. |
| 1 | `glow_organelles` | Yellow glow + chloroplast shrink | **model swap** | Swaps to `kloroplasSolo` + `chloroplastHighlight` overlay (green glow, not yellow material). Native material glow **missing**. |
| 1 | `play_shrink_animation` | Vacuole deflates | **model swap** | Swaps to `vakuolaMainSolo` + `vacuoleDamage` overlay + opacity 0.85. No animation clips (E0: 0 clips) — anim **missing**. |
| 2 | `focus_sample_b` | Focus Sampel B membrane | **live tabletop AR** | Primary → `sampleB`; membrane highlight flag; overlay none. |
| 2 | `zoom_membrane` | Zoom to outer layer | **camera orbit** (fallback) / approx live | Same pattern as M1 zoom: orbit in ModelViewer; live = scale 1.2 + `membraneDamage` overlay. |
| 2 | `show_torn_bilayer` | Torn phospholipid bilayer | **model swap** | Swaps to `RantaiProtein` proxy + membrane overlay. Dedicated torn-bilayer GLB **missing** (E0 gap). |
| 2 | `play_leak_particles` | Blue water particle system | **missing** (native) / overlay stub | `ArOverlayEffect.waterLeak` Flutter paint only. Plugin has no particle emitter (E0 Fail). |
| 3 | `show_both_samples` | Side-by-side A+B | **live tabletop AR** | `sampleA` + `setSecondaryModel(sampleB)` + `comparisonLabels`. Live: two nodes on same anchor. Fallback: dual ModelViewer row. |
| 3 | `highlight_cell_wall` | Green contour on dinding sel | **model swap** | Swaps primary to `dindingSelSolo` + `cellWallHighlight` overlay (amber glow in painter — not green contour). |
| 3 | `mark_sample_b` | Red X on Sample B (no wall) | **live tabletop AR** | Restores A+B pair + `missingStructureCross` overlay. |
| 3 | `show_force_arrows` | 3D force arrows | **model swap** + overlay | Registry maps step → `mitokondriaSolo` (odd asset choice) + `forceArrows` overlay. Dedicated force-arrow GLB **missing**. |

**Score (12 steps):** live tabletop AR **4** · model swap **5** · camera orbit **2** (fallback-primary) · missing **1** (native particles; plus several *approximate* cells above).

### Plugin limits (`ar_flutter_plugin_2`)

| Capability | Status |
|---|---|
| Horizontal plane + tap place + stable `ARPlaneAnchor` | Pass |
| Local GLB load (`fileSystemAppFolderGLB`) | Pass |
| Animation clip control | Fail (0 clips in inventory) |
| Native material glow / opacity API | Partial / not exposed — approximated via GLB swap + Flutter overlay |
| Particle emitter | Fail — `waterLeak` overlay only |
| Smooth AR camera dolly / orbit toward node | Fail — no `focusOnTarget` / `smoothZoomToTarget` |
| Organelle mesh hit-test | Fail — UI buttons stand in |

### Eager `model_viewer_plus` fallback?

| Condition | Behavior |
|---|---|
| `StudentJourney.arSupported == false` | Immediate Fake engine + ModelViewer; `_fallbackReady = true` post-frame place |
| Fatal live init (`not supported` / `unavailable` / ARCore fail) **before** place | Soft fallback: `_liveInitFailed` → ModelViewer; sequence unchanged |
| Successful plane place | **Stays** on `ARView` — ModelViewer never opened mid-sequence |
| All ModelViewer instances | `loading: Loading.eager` |
| Mid-sequence healthy ARCore | Does **not** eagerly fall back (by design, E11-A) |

### Anchor lifecycle

1. Scene 1: plane tap → single `ARPlaneAnchor` → `initLabScene` (Meja + Sample A + Sample B).  
2. Misi 1–3 steps: **same anchor**; `_replacePrimaryModel` / secondary add-remove only.  
3. Re-tap plane after placed: intentional **new** anchor (reposisi) — not a sequence side effect.  
4. `SequenceEngine` holds no placement state — cannot clear the tabletop.  
5. Tracking lost → `isPaused` queues `runAction`; resume does not re-place.  
6. Gap: `resetTransform()` clears sequence `nodeScale`/`nodePosition` (see Interaction Audit FAIL).

### ArSceneEngine API — existing vs desired

| Desired API | Existing? | Notes |
|---|---|---|
| `focusOnTarget` | **No** | Desired for PDF smooth zoom-to-organelle |
| `smoothZoomToTarget` | **No** | Approximated: fallback `cameraOrbit` + live `setNodeScale` |
| `showNode` / `hideNode` | **Yes** | Visibility map in `ArSceneVisualState` |
| `replaceNodeModel` | **Partial** | `replaceModelAtActiveAnchor` (primary only); no per-`nodeId` path |
| `setNodeScale` / `setNodePosition` / `setNodeRotation` | **Yes** | State stored; live sync applies mainly to primary/lab/secondary nodes — organelle nodeIds are logical only |
| `setMaterialHighlight` | **Yes** | Sets `highlightTarget`; rendered as Flutter overlay, not native material |
| `setOutline` | **No** | Cell-wall “contour” is overlay glow |
| `setOpacity` | **Yes** | Global opacity → overlay layer |
| `showAnchoredOverlay` | **Partial** | `showAnchoredOverlayEffect(ArOverlayEffect)` |
| `showParticleOverlay` | **Partial** | Covered by `ArOverlayEffect.waterLeak` only |
| `resetSceneFocus` | **No** | Closest: `resetTransform` + AI `reset_scene` (clears overlays/secondary; over-clears node transforms) |

### Concise gap matrix (copy-ready)

```
MISI-1  focus_sample_a        → live tabletop AR
        zoom_internal         → camera orbit (fallback) | live approx scale — true AR zoom MISSING
        glow_organelles       → model swap (+ overlay glow; yellow material MISSING)
        play_shrink_animation → model swap (+ overlay; anim clip MISSING)

MISI-2  focus_sample_b        → live tabletop AR
        zoom_membrane         → camera orbit (fallback) | live approx scale
        show_torn_bilayer     → model swap (RantaiProtein proxy)
        play_leak_particles   → MISSING native particles (Flutter waterLeak stub)

MISI-3  show_both_samples     → live tabletop AR
        highlight_cell_wall   → model swap (+ overlay; green contour MISSING)
        mark_sample_b         → live tabletop AR (red X overlay)
        show_force_arrows     → model swap + overlay (dedicated arrow GLB MISSING)
```

---

## Wave 1 — Interaction Audit

**Scope:** `lib/ar/*`, `mission_scene_panel.dart`, `ar_scene_engine.dart` (+ parent pause wiring in `mission_screen.dart`).  
**Mode:** AUDIT ONLY (no code changes).  
**Date:** 2026-07-26.

### Interaction table

| Criterion | Result | Evidence (`file:line`) | Notes |
|---|---|---|---|
| Pinch-scale vs sequence | **PASS** | `mission_scene_panel.dart:363-375`, `:411-415`; `ar_scene_engine.dart:507-513` | Perbesar/Perkecil only call `setUserTransform(scale:)` — never `onRunStep` / `runAction`. Disabled when `sequencePaused`. Live AR uses button approximation (not native two-finger pinch). Fallback ModelViewer has real pinch via `cameraControls` (`:594-595`, `:611-612`, `:632-633`). |
| Drag/rotate vs anchor | **PASS** | `mission_scene_panel.dart:377-380`, `:418-422`, `:825-837`, `:978-992` | Putar nudges `userRotationY` on the same placed nodes; sequence GLB swaps keep `ARPlaneAnchor`. Plane re-tap intentionally creates a **new** anchor (reposisi), not step change. No live finger-drag of nodes — only button rotate + fallback camera drag. |
| Reset transform | **FAIL** | `mission_scene_panel.dart:382-385`, `:425-430`; `ar_scene_engine.dart:475-484` | UI resets gesture scale/rotation and calls `resetTransform()`. Engine clears `userScale`/`userRotationY` **and** wipes `nodeScale` / `nodeRotationY` / `nodePosition`, which erases sequence director transforms (e.g. `zoom_internal`). Placement is preserved; step index is not advanced — but current-step visuals are corrupted. |
| Tap organelle | **PASS** | `mission_scene_panel.dart:387-400`, `:433-449`; `ar_scene_engine.dart:452-461` | “Ketuk kloroplas / membran” selects structure + `setMaterialHighlight` only — no sequence advance. Gated when paused. Not mesh hit-test (plugin has no organelle node picking); UI buttons stand in. |
| Tracking lost pause | **PASS** | `mission_scene_panel.dart:747-754`, `:365-399`, `:808`, `:905`, `:696-711`; `mission_screen.dart:60`, `:266-267`, `:429`; `ar_scene_engine.dart:302`, `:360-375` | Tracking-loss errors → `updateTracking(lost)` → parent `sequencePaused` via `isPaused`. Gestures, plane tap, node sync, and Jalankan Langkah all gated; overlay `mission-tracking-lost` shown. |
| Resume same step | **PASS*** | `ar_scene_engine.dart:360-416`; `ar_lifecycle_controller.dart:43-61`; `mission_screen.dart:167-197`, `:246-248`, `:293-302`; `mission_scene_panel.dart:157-165`, `:737-738` | Sequence index / `SequenceState` retained; `runAction` queues while paused and completes on healthy tracking without inventing a new step. Lifecycle resume stays lost until `confirmRelocalized`. *Caveat:* if pause hits after `setState` advanced the step but before `applySequenceStep`, visuals may not re-apply until the next step change (`:186`, `:296-301`). |
| Lifecycle pause | **PASS** | `ar_lifecycle_controller.dart:23-61`; `mission_scene_panel.dart:155-167`; `test/ar/ar_lifecycle_controller_test.dart` | `inactive`/`paused`/`hidden` → tracking lost; `resumed` does not force healthy tracking. Fallback 3D auto-`confirmRelocalized` on resume; live AR waits for plane/place/debug OK. |
| Eager `model_viewer` fallback | **PASS** | `mission_scene_panel.dart:36-38`, `:95-96`, `:129-138`, `:577-637`, `:762-776`, `:792-802` | All `ModelViewer` instances use `loading: Loading.eager`. Soft fallback only on fatal init **before** successful place (or Mode 3D / debug force). Successful place keeps live ARView. |

### Summary score

| Pass | Fail | Partial caveats |
|---|---|---|
| 7 | 1 (`resetTransform` over-clear) | Button pinch/rotate (not native gestures); organelle tap via UI not mesh; resume may skip visual re-apply |

### Wave 2 — Fix recommendations

1. **Split user vs sequence transforms in `resetTransform`** (`ar_scene_engine.dart:475-484`)  
   Reset only `userScale` / `userRotationY`. Do **not** clear `nodeScale` / `nodePosition` / `nodeRotationY` (or re-apply current `stepCode` via `ArVisualDirector` after reset). Update AI `reset_scene` path accordingly (`ar_visual_director.dart:209-217`).

2. **Re-apply step visuals on tracking recovery**  
   When `confirmRelocalized` / tracking returns to healthy, if `stepCode != null`, call `_applyStepVisuals()` so a mid-step pause does not leave a bare model.

3. **Native pinch / rotate on live AR (optional DoD)**  
   Replace or supplement Perbesar/Putar buttons with `ScaleGestureRecognizer` / pan on the AR overlay that maps to `setUserTransform`, still gated by `sequencePaused`, never touching `SequenceEngine`.

4. **Organelle mesh pick (if plugin allows)**  
   Prefer node/hit callbacks over labeled buttons; keep highlight-only semantics (no sequence side effects). Document plugin gap if unavailable.

5. **Guard `_playSequenceFromCode` while paused** (`mission_screen.dart:345-357`)  
   Do not call `completeCurrentStep` when `_sequencePaused` — today the loop can advance indices without visuals/actions.

6. **Apply `visual.nodeScale` in `_applyUserTransformToNodes`**  
   Multiply director node scales with `_gestureScale` so pinch does not silently ignore sequence zoom directives (fidelity, not only interaction).

7. **Widget tests for gesture isolation**  
   Extend `test/ar/mission_scene_persistence_test.dart`: tap Perbesar/Putar/Reset/organelle → assert placement + step unchanged; assert `resetTransform` preserves `nodeScale` after Wave 2 fix; assert gestures `onPressed == null` when `sequencePaused`.

8. **ModelViewer remount vs eager load**  
   Keys include `$_activeAsset` (`:589`, `:627`) so step swaps remount the viewer; eager loading mitigates flash — consider mission-stable key + `src` update if remount jank appears on device.

---

## Wave 2 — Engine API

**Owner:** `lib/ar/ar_scene_engine.dart` (`LiveArSceneEngine` + `FakeArSceneEngine` via `ControllableArSceneEngine`)  
**Branch:** `wave2/ar-engine-api`  
**Date:** 2026-07-26

### Methods added / finalized

| Method | Behavior | Placement safe? |
|---|---|---|
| `focusOnTarget(nodeId)` | Sets `focusTarget` + `highlightTarget`; ensures node visible | Yes |
| `smoothZoomToTarget(nodeId, {factor, cameraOrbit})` | Sets `zoomTarget`/`zoomFactor`; scales node as live approx; stores `cameraOrbit` for ModelViewer fallback | Yes |
| `showNode` / `hideNode` | Visibility map (unchanged) | Yes |
| `replaceNodeModel(nodeId, assetPath)` | Per-node GLB path in `nodeModels`; maps primary/sampleA → `activeModelPath`, sampleB → secondary, labTable → lab path | Yes (same anchor) |
| `setNodeScale` / `setNodePosition` / `setNodeRotation` | Sequence transforms (unchanged) | Yes |
| `setMaterialHighlight` | `highlightTarget` → Flutter glow overlay | Yes |
| `setOutline(nodeId, {enabled})` | `outlineTarget` → Flutter contour overlay (no native outline) | Yes |
| `setOpacity` | Global opacity (unchanged) | Yes |
| `showAnchoredOverlay(effect)` | Preferred name for anchored Flutter overlays | Yes |
| `showParticleOverlay(effect)` | Particle-oriented alias → same overlay slot (`waterLeak`, etc.) | Yes |
| `resetSceneFocus()` | Clears focus/zoom/highlight/outline/`cameraOrbit`; restores pre-zoom node scale only | Yes |
| `replaceModelAtActiveAnchor` | Delegates to `replaceNodeModel(primary, …)` | Yes |
| `showAnchoredOverlayEffect` | Compat alias → `showAnchoredOverlay` | Yes |
| `resetTransform()` | **Fixed:** resets `userScale`/`userRotationY` only — preserves sequence `nodeScale`/`nodePosition`/`nodeRotationY` | Yes |

### Visual state fields added

`focusTarget`, `zoomTarget`, `zoomFactor`, `cameraOrbit`, `outlineTarget`, `nodeModels`.

### Plugin limits (still approximated)

| Capability | Plugin (`ar_flutter_plugin_2`) | Engine approximation |
|---|---|---|
| AR camera dolly / orbit to organelle | **Fail** | `smoothZoomToTarget` → node scale + optional `cameraOrbit` for fallback ModelViewer |
| Native material glow / tint | **Fail / not exposed** | `setMaterialHighlight` + overlay agents |
| Native mesh outline / contour | **Fail** | `setOutline` → `outlineTarget` for Flutter painter |
| Particle emitter | **Fail** | `showParticleOverlay` → `ArOverlayEffect` (e.g. `waterLeak`) |
| Per-organelle mesh nodes | **Partial** (logical ids only) | `nodeModels` + GLB swap on primary/secondary |
| Stable plane anchor across sequence | **Pass** | All Wave 2 APIs forbid mid-sequence `place`/`reset` |

### Non-goals (this wave)

- Does **not** force `model_viewer` fallback (live activation owned elsewhere).
- Does **not** change group/session/LKPD/POS/auth flows.
- Overlay painters / mission directors consume these APIs in sibling Wave 2 agents.

---

## Wave 2 — Overlays

**Mode:** IMPLEMENT (Flutter overlays bound to AR targets).  
**Date:** 2026-07-26.  
**Branch:** `wave2/ar-overlay-effects`  
**Owns:** `lib/ar/ar_overlay_frame.dart`, `lib/ar/ar_overlay_painters.dart`, `lib/ar/ar_scene_overlays.dart`; wiring in `mission_scene_panel.dart`.  
**Does not edit:** `ar_scene_engine.dart` (uses existing `showAnchoredOverlayEffect` / `ArOverlayEffect`).

### Why overlays

`ar_flutter_plugin_2` has no native material glow and no particle emitter (E0 / Wave 1). Mission beats that need those cues are realized as model-frame Flutter paints on top of live `ARView` and ModelViewer fallback.

### Overlay list (PDF-aligned)

| Overlay | Effect enum | Mission | Visual |
|---|---|---|---|
| Yellow chloroplast glow | `chloroplastHighlight` | M1 `glow_organelles` / `zoom_internal` | Soft yellow radial glow + inner core on kloroplas (left of Sample A) — was green |
| Vacuole shrink rings | `vacuoleDamage` | M1 `play_shrink_animation` | Cyan glow + concentric shrink rings on Sample A |
| Membrane tear ring | `membraneDamage` | M2 zoom / torn bilayer | Red dashed ring on outer membrane |
| Dark-blue water particles | `waterLeak` | M2 `play_leak_particles` | Animated deep-blue droplets spraying **from membrane rim only** (not fullscreen) |
| Green cell-wall contour | `cellWallHighlight` | M3 `highlight_cell_wall` | Green double contour / outline on Sample A — was amber glow |
| Red cross on Sample B | `missingStructureCross` | M3 `mark_sample_b` | Red X + label anchored to Sample B (right when dual) |
| Force arrows | `forceArrows` | M3 `show_force_arrows` | 8 radial inward amber arrows on Sample A; outward red cues on Sample B when dual |
| Comparison labels | `comparisonLabels` | M3 `show_both_samples` | Sampel A / Sampel B labels at dual anchors |

### Frame binding

`ArOverlayFrame` maps the scene rect to Sample A (center or left) and Sample B (right when `dualSamples`). `mission_scene_panel` passes `dualSamples: visual.secondaryModelPath != null` for live AR, ModelViewer fallback, and test placeholder — same overlay layer on all three paths.

### Animation

`ArSceneOverlayLayer` is stateful with a repeating ticker for `waterLeak`, `chloroplastHighlight`, and `forceArrows` so particles/glow stay alive without native emitters.

---

## Wave 2 — Misi 1

**Branch:** `wave2/misi-1`  
**Owner:** mission-1-agent  
**Date:** 2026-07-26  
**Scope:** SEQ-MISI-1 only (`lib/ar/misi1_visuals.dart`, M1 cases in `ar_visual_director.dart`, `MissionSequences.misi1`, M1 camera orbits, yellow chloroplast overlay color). Does **not** rewrite `ar_scene_engine.dart`.

### Visual steps (PDF SoT → live tabletop)

| Step | Asset | Live AR behavior | Fallback ModelViewer |
|---|---|---|---|
| `focus_sample_a` | `sampleA` AllInOne | Clear secondary / Sample B; highlight Sample A; reset organelle scales; **same lab-table anchor** | Orbit `0deg 72deg 2.0m` |
| `zoom_internal` | stays `sampleA` | Primary scale **1.55** + slight Y lift (through-wall approx); focus kloroplas+vakuola scales; **no** yellow glow yet | Orbit `0deg 58deg 1.05m` |
| `glow_organelles` | `KlooroPlas_Solo` | Yellow `chloroplastHighlight` overlay (`#FACC15`); chloroplast scale **0.72** (shrunk/damaged) | Orbit `35deg 50deg 1.35m` |
| `play_shrink_animation` | `VakolaMain_Solo` | `vacuoleDamage` overlay; vacuole scale **0.55** (deflated); opacity 0.82 — **SEQ ends here** (no auto M2) | Orbit `25deg 65deg 1.25m` |

### Engine API gap (documented, not implemented here)

| Desired | Status |
|---|---|
| `smoothZoomToTarget` / `focusOnTarget` | **Needed** for true AR dolly — currently approximated via `setNodeScale` + `setNodePosition` in `Misi1Visuals.zoomInternal` |
| Native yellow material | **Unavailable** — Flutter overlay yellow glow |

### Guarantees

- Placement / `labTableModelPath` never cleared by M1 steps.
- `MissionSequences.misi1` still four steps only; sequence engine does not start M2/M3.
- Group / session / LKPD flows untouched.

---

## Wave 2 — Misi 2

**Owner:** mission-2-agent (`wave2/misi-2-visual`)  
**Scope:** `SEQ-MISI-2` visuals only — `ar_visual_director.dart` M2 cases, `sequence_engine.dart` M2 docs/order, `misi2_visual_helpers.dart`, membrane-anchored `waterLeak` paint. **Did not** edit `ar_scene_engine.dart`.  
**Date:** 2026-07-26.  
**PDF SoT:** Zoom ke lapisan terluar Sampel B → bilayer diperbesar (normal) → ekor fosfolipid terputus (robek) → partikel air biru tua menyembur dari dalam sel / area membran.

### Visual steps (tabletop, same lab anchor)

| # | Step code | Visual | Assets / overlay |
|---|---|---|---|
| 1 | `focus_sample_b` | Focus Sampel B outer; membrane highlight; clear secondary | `SelHewanBroken.glb` · overlay `none` |
| 2 | `zoom_membrane` | Zoom bilayer **intact** (normal) — scale-up primary + membrane; **no** damage ring yet | `SelHewanBroken.glb` · overlay `none` |
| 3 | `show_torn_bilayer` | Torn phospholipid bilayer (broken hydrophobic tails) | `RantaiProtein.glb` proxy · `membraneDamage` |
| 4 | `play_leak_particles` | Dark-blue (`#1E3A8A`) water spheres spray **from membrane rim** (not fullscreen) | Keep `RantaiProtein` · `waterLeak` + `highlightTarget=membrane` |

### Fixes vs Wave 1 gaps

| Wave 1 gap | Wave 2 change |
|---|---|
| `zoom_membrane` also showed `membraneDamage` (conflated normal/torn) | Intact zoom has `overlay=none`; damage only on `show_torn_bilayer` |
| Leak was light-blue drops, not membrane-local | `_membraneWaterSpray` dark-blue radial exit from membrane origin when `highlightTarget == membrane` |
| Leak highlight not forced to membrane | `Misi2VisualHelpers.playMembraneLeakParticles` always sets membrane highlight |

### Guarantees

- Placement / `labTableModelPath` preserved across all four steps (no re-place).
- Sequence order unchanged: `focus → zoom (normal) → torn → leak`.
- Native particle emitter still unavailable — Flutter anchored overlay stands in (E0 Fail).

---

## Wave 2 — Misi 3

**Mode:** IMPLEMENT (Misi 3 / SEQ-MISI-3 only).  
**Branch:** `wave2/misi-3`  
**Date:** 2026-07-26.  
**Owned files:** `misi3_visuals.dart`, `ar_visual_director.dart` (M3 cases), `sequence_engine.dart` (SEQ-MISI-3 docs), `ar_asset_registry.dart` (M3 `modelForStep`), `ar_scene_overlays.dart` (green contour + force arrows).  
**Out of scope:** `ar_scene_engine.dart` (not edited).

### PDF visual steps (realized)

| Step | Code | Visual |
|---|---|---|
| 1 | `show_both_samples` | Sampel A + Sampel B side-by-side on same tabletop (`offsetX: 0.14`, matched `ArVec3.one` proportions) + comparison labels |
| 2 | `highlight_cell_wall` | Primary → `DindingSel_Solo`; Sample B secondary; green cell-wall contour overlay (`cellWallHighlight`) |
| 3 | `mark_sample_b` | Restore A+B pair; red X on B (`missingStructureCross` — “Tidak ada dinding sel”) |
| 4 | `show_force_arrows` | Stay on **dinding/sampleA** (`dindingSelSolo`) + Sample B; `forceArrows` overlay (amber inward pressure + green resistance). **Not** `mitokondriaSolo` |

### Wave 1 bug fix

| Before | After |
|---|---|
| `modelForStep('MISI-3','show_force_arrows')` → `mitokondriaSolo` | → `dindingSelSolo` |
| Director only set secondary + overlay | `Misi3Visuals.showForceArrows` re-pairs dinding + B, highlights cell wall, force-arrows overlay |
| `mark_sample_b` registry → `sampleB` (then director restored A) | → `sampleA` (matches A+B pair) |
| `cellWallHighlight` amber glow | Green glow + contour ring (`#22C55E` / `#16A34A`) |

### Verification

- `test/ar/ar_visual_director_test.dart` — full M3 beat + asserts active model ≠ `mitokondriaSolo`
- Placement preserved across all four SEQ-MISI-3 steps

---

## Wave 3 — Merge

**Date:** 2026-07-26  
**Target:** `main` workspace `/Users/macbookm2/CellForensic`  
**Order:** `wave2/ar-engine-api` → `wave2/ar-overlay-effects` → `wave2/misi-1` → `wave2/misi-2-visual` → `wave2/misi-3`

### Conflicts resolved

| File | Resolution |
|---|---|
| `lib/ar/ar_scene_engine.dart` | Engine branch only (no mission conflict) — focus/zoom/outline APIs + **user-only `resetTransform`** |
| `lib/ar/ar_visual_director.dart` | **All** M1 + M2 + M3 cases kept via `Misi1Visuals` / `Misi2VisualHelpers` / `Misi3Visuals` |
| `lib/ar/ar_scene_overlays.dart` | Overlay painters (`ar_overlay_painters.dart`) win; mission comments retained (yellow glow, membrane leak, green contour / force arrows) |
| `docs/E10_AR_VISUAL_FIDELITY.md` | Concatenated all Wave 2 sections (Engine, Overlays, Misi 1–3) |

### Invariants preserved

- M3 `show_force_arrows` → `dindingSelSolo` (not `mitokondriaSolo`)
- M2 `waterLeak` membrane-anchored (`highlightTarget=membrane` + rim spray painter)
- `resetTransform` resets `userScale` / `userRotationY` only
- Group → Scene1 / intent-driven missions / no auto-start M1 untouched
- Live-AR agent `67216d2e` left **no** uncommitted fixes (diagnosis incomplete)

### Merged commits on `main`

`d8e1f9f` engine → `4fbe412` overlays → `e02d697` M1 → `7a899a9` M2 → `a782aaf` M3 (+ Wave 3 merge commits)
