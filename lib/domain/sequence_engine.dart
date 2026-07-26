/// Intent-driven AR action sequencing for the three investigation missions.
///
/// This engine is deliberately **not** a linear "auto wizard": it does not walk
/// a generic list on its own, and it never advances the mission. Instead a
/// sequence is selected by *mission intent* (Misi 1/2/3) via [startSequence]
/// and only begins when explicitly asked (student presses "Jalankan Langkah"
/// or a whitelisted AI intent triggers it). Each [SequenceStep.code] is a
/// stable contract with the AR layer (`ArVisualDirector.applySequenceStep`):
/// AR turns each code into anchored visuals **on the same lab-table anchor**,
/// so advancing a step never re-places, re-anchors, or resets the tabletop.
///
/// Guarantees this engine upholds:
/// * **Anchor preserved** — the engine only emits step codes; it has no anchor,
///   placement, or transform state, so it cannot clear the lab-table anchor.
/// * **No auto missionIndex increment** — the engine has no notion of "next
///   mission". Mission advancement lives in `StudentJourney.completeActiveMission`.
/// * **Intent-driven start** — nothing runs until [start]/[startSequence] is
///   called for a specific mission.
/// * **Single completion signal** — completion is emitted exactly once at the
///   transition into [SequenceStatus.completed]; re-running a finished sequence
///   returns the same state (see [completeCurrentStep]). De-duplication of the
///   *logbook* completion is owned by mission-state, not this engine.
class SequenceStep {
  const SequenceStep({required this.code});

  final String code;
}

class SequenceConfig {
  const SequenceConfig({required this.code, required this.steps});

  final String code;
  final List<SequenceStep> steps;
}

enum SequenceStatus { running, completed }

class SequenceState {
  const SequenceState({
    required this.config,
    required this.status,
    required this.stepIndex,
    required this.completionEventCount,
  });

  final SequenceConfig config;
  final SequenceStatus status;
  final int stepIndex;

  /// `1` only on the state that just transitioned into [SequenceStatus.completed]
  /// (or a restored/rebuilt completed state); `0` while running. Used as the
  /// one-shot "sequence finished" signal for the logbook completion gate.
  final int completionEventCount;

  SequenceStep? get currentStep =>
      status == SequenceStatus.running ? config.steps[stepIndex] : null;

  /// Whether this state carries the completion signal that unlocks the
  /// "Selesaikan Misi" / logbook step. Idempotent by design — mission-state is
  /// responsible for not writing a duplicate completion on re-run/restore.
  bool get signalsCompletion =>
      status == SequenceStatus.completed && completionEventCount > 0;
}

/// Stable AR action codes emitted per mission step.
///
/// These are the source-of-truth identifiers shared with the AR layer. AR
/// (`ArVisualDirector` / `ArSceneEngine`) already implements a visual for each
/// code; the engine must only ever emit codes from this set so no step lands on
/// AR's `default: break` (a visually dead step). If a new beat is ever needed,
/// add the code here first and hand it to the AR agent to implement.
abstract final class SequenceStepCodes {
  // --- Misi 1: investigate Sample A internal structure ---
  /// Focus Sample A, clear any comparison/secondary model.
  static const focusSampleA = 'focus_sample_a';

  /// Smooth zoom-in through the cell wall toward the internal organelles.
  static const zoomInternal = 'zoom_internal';

  /// Yellow glow highlight on the chloroplast **and** shrink it (damaged).
  static const glowOrganelles = 'glow_organelles';

  /// Deflate the giant vacuole (vacuole-damage overlay).
  static const playShrinkAnimation = 'play_shrink_animation';

  // --- Misi 2: investigate Sample B membrane ---
  /// Focus Sample B outer layer / membrane.
  static const focusSampleB = 'focus_sample_b';

  /// Zoom into the phospholipid bilayer.
  static const zoomMembrane = 'zoom_membrane';

  /// Show the torn bilayer (broken hydrophobic tails).
  static const showTornBilayer = 'show_torn_bilayer';

  /// Blue water particles leaking out of the cell.
  static const playLeakParticles = 'play_leak_particles';

  // --- Misi 3: compare outer layers of A and B ---
  /// Show Sample A + Sample B side-by-side on the same tabletop anchor.
  static const showBothSamples = 'show_both_samples';

  /// Green contour highlight on Sample A's cell wall.
  static const highlightCellWall = 'highlight_cell_wall';

  /// Red cross on Sample B (no cell wall).
  static const markSampleB = 'mark_sample_b';

  /// 3D force arrows: the cell wall resists external pressure.
  static const showForceArrows = 'show_force_arrows';
}

/// Canonical, intent-keyed sequence definitions for the three missions.
///
/// This is the source of truth for *which* AR actions run for each mission and
/// in what order. Content packs and the mission UI resolve sequences from here
/// (via [forMission] / [forCode]) instead of hardcoding step lists, so the
/// "correct sequence per mission intent" lives in one place.
abstract final class MissionSequences {
  /// Misi 1 — focus A → zoom through cell wall → yellow chloroplast highlight
  /// (shrunk chloroplast) → deflated giant vacuole.
  ///
  /// Five described beats, four step codes: [SequenceStepCodes.glowOrganelles]
  /// covers both the yellow highlight and the chloroplast shrink.
  static const misi1 = SequenceConfig(
    code: 'SEQ-MISI-1',
    steps: [
      SequenceStep(code: SequenceStepCodes.focusSampleA),
      SequenceStep(code: SequenceStepCodes.zoomInternal),
      SequenceStep(code: SequenceStepCodes.glowOrganelles),
      SequenceStep(code: SequenceStepCodes.playShrinkAnimation),
    ],
  );

  /// Misi 2 — focus B outer → zoom bilayer → torn bilayer → blue water
  /// particles leaking out.
  static const misi2 = SequenceConfig(
    code: 'SEQ-MISI-2',
    steps: [
      SequenceStep(code: SequenceStepCodes.focusSampleB),
      SequenceStep(code: SequenceStepCodes.zoomMembrane),
      SequenceStep(code: SequenceStepCodes.showTornBilayer),
      SequenceStep(code: SequenceStepCodes.playLeakParticles),
    ],
  );

  /// Misi 3 — PDF Scene 2 comparison (SEQ-MISI-3 only; does not chain M1/M2):
  /// 1. A+B side-by-side on tabletop (matched proportions)
  /// 2. green cell-wall contour on A (`DindingSel_Solo`)
  /// 3. red X on B (no wall)
  /// 4. force arrows — wall resists pressure (stay dinding/sampleA; never
  ///    swap to mitokondriaSolo)
  static const misi3 = SequenceConfig(
    code: 'SEQ-MISI-3',
    steps: [
      SequenceStep(code: SequenceStepCodes.showBothSamples),
      SequenceStep(code: SequenceStepCodes.highlightCellWall),
      SequenceStep(code: SequenceStepCodes.markSampleB),
      SequenceStep(code: SequenceStepCodes.showForceArrows),
    ],
  );

  /// Resolves the sequence for a 1-based mission intent (1/2/3).
  ///
  /// Returns `null` for unknown ids — the engine never guesses a sequence.
  static SequenceConfig? forMission(int missionId) => switch (missionId) {
    1 => misi1,
    2 => misi2,
    3 => misi3,
    _ => null,
  };

  /// Resolves a content-pack / IntentMatch sequence code (`SEQ-MISI-1`) or a
  /// mission code (`MISI-1`) to the canonical [SequenceConfig].
  ///
  /// Returns `null` for unknown codes — callers must not invent a sequence.
  static SequenceConfig? forSequenceCode(String sequenceCode) =>
      switch (sequenceCode.trim().toUpperCase()) {
        'SEQ-MISI-1' || 'MISI-1' => misi1,
        'SEQ-MISI-2' || 'MISI-2' => misi2,
        'SEQ-MISI-3' || 'MISI-3' => misi3,
        _ => null,
      };

  /// Resolves the sequence for a mission code such as `MISI-1`.
  static SequenceConfig? forCode(String missionCode) =>
      forSequenceCode(missionCode);

  /// Mission UI / AR code (`MISI-1`) for a sequence config code.
  static String? missionCodeFor(SequenceConfig config) => switch (config.code) {
    'SEQ-MISI-1' => 'MISI-1',
    'SEQ-MISI-2' => 'MISI-2',
    'SEQ-MISI-3' => 'MISI-3',
    _ => null,
  };
}

class SequenceEngine {
  const SequenceEngine();

  /// Starts an explicit [config]. Empty configs finish immediately with a
  /// single completion signal.
  SequenceState start(SequenceConfig config) => SequenceState(
    config: config,
    status: config.steps.isEmpty
        ? SequenceStatus.completed
        : SequenceStatus.running,
    stepIndex: 0,
    completionEventCount: config.steps.isEmpty ? 1 : 0,
  );

  /// Intent-driven entry point: build and start the correct AR action sequence
  /// for mission [missionId] (1/2/3).
  ///
  /// Returns `null` when [missionId] is not a known mission, leaving the caller
  /// in control — the engine never auto-selects or auto-advances a mission.
  /// This only runs when explicitly invoked (student action / whitelisted AI
  /// intent), satisfying the "sequence starts only when asked" rule.
  SequenceState? startSequence(int missionId) {
    final config = MissionSequences.forMission(missionId);
    if (config == null) return null;
    return start(config);
  }

  /// Same as [startSequence] but keyed by mission code (e.g. `MISI-2`).
  SequenceState? startSequenceForCode(String missionCode) {
    final config = MissionSequences.forCode(missionCode);
    if (config == null) return null;
    return start(config);
  }

  /// Starts the AR sequence for an IntentMatch / content-pack [sequenceCode]
  /// such as `SEQ-MISI-1`. Used by the offline question → AR path.
  SequenceState? startForSequenceCode(String sequenceCode) {
    final config = MissionSequences.forSequenceCode(sequenceCode);
    if (config == null) return null;
    return start(config);
  }

  /// Advances one step. On the final step it transitions to
  /// [SequenceStatus.completed] and raises the one-shot completion signal.
  ///
  /// Re-running a completed sequence returns the *same* state instance (no new
  /// completion), so listeners diffing state never see a duplicate completion.
  SequenceState completeCurrentStep(SequenceState state) {
    if (state.status == SequenceStatus.completed) return state;

    final nextIndex = state.stepIndex + 1;
    final completed = nextIndex == state.config.steps.length;
    return SequenceState(
      config: state.config,
      status: completed ? SequenceStatus.completed : SequenceStatus.running,
      stepIndex: nextIndex,
      completionEventCount: completed ? 1 : 0,
    );
  }

  /// Rebuilds a sequence state at a persisted position without re-emitting a
  /// completion signal — used when restoring mid-mission progress from an
  /// autosave/snapshot so a resumed session does not re-fire logbook completion.
  ///
  /// [stepIndex] is clamped into range. When [completed] is true (or all steps
  /// are consumed) the state is [SequenceStatus.completed] but with
  /// `completionEventCount == 0`, because completion already happened in a
  /// prior session and mission-state owns that record.
  SequenceState restore(
    SequenceConfig config, {
    int stepIndex = 0,
    bool completed = false,
  }) {
    final total = config.steps.length;
    final clamped = stepIndex.clamp(0, total);
    final isDone = completed || total == 0 || clamped >= total;
    return SequenceState(
      config: config,
      status: isDone ? SequenceStatus.completed : SequenceStatus.running,
      stepIndex: isDone ? total : clamped,
      completionEventCount: 0,
    );
  }
}
