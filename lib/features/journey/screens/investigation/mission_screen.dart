import 'dart:async';

import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/ar_visual_director.dart';
import 'package:cell_forensic/ar/mission_scene_panel.dart';
import 'package:cell_forensic/ar/organelle_hotspot.dart';
import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/domain/ai/ai_assistant_client.dart';
import 'package:cell_forensic/domain/ai/ar_action_whitelist.dart';
import 'package:cell_forensic/domain/intent_matcher.dart';
import 'package:cell_forensic/domain/mission_progress.dart';
import 'package:cell_forensic/domain/sequence_engine.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/ui/features/assistant/assistant_view_model.dart';
import 'package:flutter/material.dart';

/// Scene 1 + intent-driven investigation surface (PDF).
///
/// Layout: ~70% AR camera / ~30% AI chat with text + mic ("Tanya Asisten AI").
/// Missions advance from matched intents — not a linear counter.
class MissionScreen extends StatefulWidget {
  const MissionScreen({required this.journey, super.key});

  final StudentJourney journey;

  /// Per-step dwell for intent autoplay (PDF progressive beats).
  ///
  /// Tests override to a short duration so intermediate frames are observable
  /// without waiting a full second per step.
  @visibleForTesting
  static Duration intentStepDwell = const Duration(milliseconds: 1000);

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  static const _sequenceEngine = SequenceEngine();
  static const _visualDirector = ArVisualDirector();

  static const _statusPreparing = 'Menyiapkan';
  static const _statusRunning = 'Berjalan';
  static const _statusCompleted = 'Selesai';
  static const _statusPaused = 'Dijeda (tracking hilang)';

  late String _missionCode;
  SequenceState? _sequence;
  ArSceneEngine? _sceneEngine;
  StreamSubscription<ArSceneEvent>? _engineEvents;
  AssistantViewModel? _assistant;

  final _assistantController = TextEditingController();
  final _assistantFocus = FocusNode();
  final Map<String, TextEditingController> _logbookControllers = {};
  final Map<String, FocusNode> _logbookFocusNodes = {};
  bool _isPlaced = false;
  bool _showLogbook = false;
  bool _engineWantsLiveAr = false;

  static const _wideBreakpoint = 860.0;

  MissionContent get _mission => widget.journey.activeMission;

  ArSceneEngine get _engine =>
      _sceneEngine ?? (throw StateError('ArSceneEngine belum siap'));

  AssistantViewModel get _assistantVm =>
      _assistant ?? (throw StateError('Assistant belum siap'));

  bool get _sequencePaused => _engine.isPaused;

  /// Shared matcher across all missions so Scene 1 can route any intent.
  IntentMatcher get _packMatcher =>
      IntentMatcher(widget.journey.content.allIntentRules);

  @override
  void initState() {
    super.initState();
    widget.journey.addListener(_onJourneyChanged);
    _bindMission(recreateEngine: true);
  }

  int get _missionNumber {
    final running = widget.journey.runningMissionNumber;
    if (running != null) return running;
    final code = _mission.code;
    if (code.startsWith('MISI-')) {
      return int.tryParse(code.substring(5)) ?? 1;
    }
    return 1;
  }

  AiAssistantClient? _resolveAiClient() {
    if (!SupabaseConfig.isConfigured || SupabaseConfig.clientOrNull == null) {
      return null;
    }
    return const SupabaseAiAssistantClient();
  }

  void _bindMission({required bool recreateEngine}) {
    _missionCode = _mission.code;
    _assistant?.dispose();
    _assistant = AssistantViewModel(
      matcher: _packMatcher,
      aiClient: _resolveAiClient(),
      missionNumber: _missionNumber,
      onArAction: (action) {
        if (action == ArActionWhitelist.none) return;
        unawaited(_applyAiArAction(action));
      },
      // Offline IntentMatcher.sequenceCode → SequenceEngine (no Supabase).
      onSequenceCode: (code) {
        unawaited(_playSequenceFromCode(code));
      },
    );
    _assistantController.clear();

    for (final controller in _logbookControllers.values) {
      controller.dispose();
    }
    _logbookControllers.clear();
    for (final node in _logbookFocusNodes.values) {
      node.dispose();
    }
    _logbookFocusNodes.clear();

    final saved = widget.journey.logbookByMission[_mission.code];
    for (final prompt in _mission.logbookPrompts) {
      _logbookControllers[prompt] = TextEditingController(
        text: saved?[prompt] ?? '',
      );
      _logbookFocusNodes[prompt] = FocusNode();
    }

    if (recreateEngine) {
      _recreateSceneEngine();
    }

    _restoreSequenceProgress();
  }

  void _recreateSceneEngine() {
    _engineEvents?.cancel();
    final previous = _sceneEngine;
    final next = widget.journey.arSupported
        ? LiveArSceneEngine()
        : FakeArSceneEngine();
    debugPrint(
      'CellForensic scene engine: '
      '${widget.journey.arSupported ? "LiveArSceneEngine" : "FakeArSceneEngine"} '
      '(arSupported=${widget.journey.arSupported})',
    );
    _sceneEngine = next;
    _engineWantsLiveAr = widget.journey.arSupported;
    // Fallback 3D: treat as placed so lab init can run; live AR waits for plane.
    final fallback3d = !widget.journey.arSupported;
    _isPlaced = fallback3d || widget.journey.labPlaced;
    previous?.dispose();
    _engineEvents = next.events.listen((event) {
      if (!mounted) return;
      if (event.type == ArSceneEventType.trackingChanged ||
          event.type == ArSceneEventType.placementCompleted ||
          event.type == ArSceneEventType.resetCompleted ||
          event.type == ArSceneEventType.visualChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    });

    if (fallback3d && !widget.journey.labPlaced) {
      widget.journey.markLabPlaced();
    }
    if (_isPlaced) {
      unawaited(_initLabScene());
    }
  }

  Future<void> _initLabScene() async {
    await _engine.initLabScene(
      labTableModelPath: ArAssetRegistry.mejaLab,
      sampleAModelPath: ArAssetRegistry.sampleA,
      sampleBModelPath: ArAssetRegistry.sampleB,
    );
    if (mounted) setState(() {});
  }

  void _restoreSequenceProgress() {
    final journey = widget.journey;
    if (journey.sequenceCompleted) {
      var state = _sequenceEngine.start(_mission.sequence);
      while (state.status == SequenceStatus.running) {
        state = _sequenceEngine.completeCurrentStep(state);
      }
      _sequence = state;
      if (!journey.arSupported) _isPlaced = true;
      return;
    }

    final stepIndex = journey.sequenceStepIndex;
    if (stepIndex == null) {
      _sequence = null;
      return;
    }

    var state = _sequenceEngine.start(_mission.sequence);
    final maxStep = _mission.sequence.steps.length;
    final target = stepIndex.clamp(0, maxStep);
    for (
      var i = 0;
      i < target && state.status == SequenceStatus.running;
      i++
    ) {
      state = _sequenceEngine.completeCurrentStep(state);
    }
    _sequence = state;
    if (!journey.arSupported) _isPlaced = true;
  }

  void _onJourneyChanged() {
    if (!mounted) return;
    // Mode 3D → live AR upgrade (same group/session): swap Fake → Live engine.
    if (widget.journey.arSupported && !_engineWantsLiveAr) {
      setState(() {
        if (_mission.code != _missionCode) {
          _bindMission(recreateEngine: true);
        } else {
          _recreateSceneEngine();
        }
      });
      return;
    }
    if (_mission.code != _missionCode) {
      setState(() => _bindMission(recreateEngine: false));
    } else {
      setState(() {});
    }
  }

  void _requestLiveAr() {
    widget.journey.enableLiveAr();
  }

  @override
  void dispose() {
    widget.journey.removeListener(_onJourneyChanged);
    _engineEvents?.cancel();
    _sceneEngine?.dispose();
    _assistant?.dispose();
    _assistantController.dispose();
    _assistantFocus.dispose();
    for (final controller in _logbookControllers.values) {
      controller.dispose();
    }
    for (final node in _logbookFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String get _statusLabel {
    if (_sequencePaused) return _statusPaused;
    if (!_isPlaced && widget.journey.arSupported) return _statusPreparing;
    final sequence = _sequence;
    if (sequence == null) {
      return widget.journey.hasRunningMission
          ? _statusPreparing
          : 'Laboratorium siap';
    }
    return sequence.status == SequenceStatus.completed
        ? _statusCompleted
        : _statusRunning;
  }

  bool get _sequenceCompleted => _sequence?.status == SequenceStatus.completed;

  String get _stepLabel {
    final sequence = _sequence;
    final totalSteps = _mission.sequence.steps.length;
    final currentStep = sequence?.currentStep;
    if (!_isPlaced && widget.journey.arSupported) {
      return 'Pindai permukaan meja untuk memunculkan Laboratorium Forensik Sel.';
    }
    if (_sequenceCompleted) return 'Semua langkah scene selesai.';
    if (_sequencePaused) {
      return 'Sequence dijeda sampai pelacakan AR pulih.';
    }
    if (!widget.journey.hasRunningMission) {
      return 'Tanya Asisten AI untuk memicu misi (Sampel A/B).';
    }
    if (currentStep == null) {
      return 'Tekan "Jalankan Langkah" untuk memulai sequence.';
    }
    final stepNumber = sequence!.stepIndex + 1;
    return 'Langkah $stepNumber dari $totalSteps: ${currentStep.code}';
  }

  Future<void> _onPlacementChanged(bool placed) async {
    setState(() => _isPlaced = placed);
    if (!placed) return;
    widget.journey.markLabPlaced();
    await _initLabScene();
  }

  Future<void> _runStep() async {
    if (_sequencePaused) return;
    if (widget.journey.arSupported && !_isPlaced) return;
    // Sequence steps only after an intent has started (or re-run) a mission.
    final status = widget.journey.missionStatus(_missionNumber);
    if (!widget.journey.hasRunningMission &&
        status != MissionStatus.completed &&
        status != MissionStatus.running) {
      return;
    }

    SequenceState? next;
    setState(() {
      final current = _sequence;
      if (current == null) {
        next = _sequenceEngine.start(_mission.sequence);
      } else if (current.status == SequenceStatus.running) {
        next = _sequenceEngine.completeCurrentStep(current);
      } else {
        next = current;
      }
      _sequence = next;
    });

    final state = next;
    if (state == null) return;

    final step = state.currentStep;
    if (step != null) {
      await _engine.runAction(step.code);
      if (!_sequencePaused) {
        await _visualDirector.applySequenceStep(
          _engine,
          missionCode: _mission.code,
          stepCode: step.code,
        );
      }
    }

    widget.journey.saveSequenceProgress(
      stepIndex: state.status == SequenceStatus.completed
          ? state.config.steps.length
          : state.stepIndex,
      completed: state.status == SequenceStatus.completed,
    );

    if (state.status == SequenceStatus.completed) {
      widget.journey.completeMissionObservation(_missionNumber);
    }
  }

  Future<void> _applyAiArAction(String action) async {
    if (_sequencePaused) return;
    await _visualDirector.applyAiAction(
      _engine,
      arAction: action,
      missionNumber: _missionNumber,
      confidence: 1,
    );
    if (mounted) setState(() {});
  }

  /// Plays every step of a PDF mission sequence on the active lab-table anchor.
  ///
  /// Called from [AssistantViewModel.onSequenceCode] after an offline (or
  /// AI-fallback) IntentMatch. Does not clear or re-place the tabletop.
  ///
  /// Wave 5: each step applies visuals, publishes mid-sequence state, then
  /// dwells so zoom → glow/torn → particles are each visible. Does **not**
  /// advance while [sequencePaused] (tracking lost / lifecycle). Resume
  /// continues the same step. Never auto-chains into the next mission.
  Future<void> _playSequenceFromCode(String sequenceCode) async {
    if (_sequencePaused) return;
    if (widget.journey.arSupported && !_isPlaced) return;

    final config = MissionSequences.forSequenceCode(sequenceCode);
    if (config == null) return;

    final missionCode =
        MissionSequences.missionCodeFor(config) ?? _mission.code;
    final missionNumber =
        int.tryParse(missionCode.replaceFirst('MISI-', '')) ?? _missionNumber;

    var state = _sequenceEngine.start(config);
    if (!mounted) return;
    setState(() => _sequence = state);
    widget.journey.saveSequenceProgress(
      stepIndex: state.stepIndex,
      completed: false,
    );

    while (state.status == SequenceStatus.running) {
      if (!mounted) return;
      await _waitWhileSequencePaused();
      if (!mounted) return;

      final step = state.currentStep;
      if (step == null) break;

      await _engine.runAction(step.code);
      await _waitWhileSequencePaused();
      if (!mounted) return;

      // Re-apply if pause interrupted mid-step — stay on same stepCode.
      await _visualDirector.applySequenceStep(
        _engine,
        missionCode: missionCode,
        stepCode: step.code,
      );

      if (!mounted) return;
      setState(() => _sequence = state);
      widget.journey.saveSequenceProgress(
        stepIndex: state.stepIndex,
        completed: false,
      );

      // Dwell so this beat is visible before advancing (no instant collapse).
      await _dwellIntentStep();
      if (!mounted) return;
      await _waitWhileSequencePaused();
      if (!mounted) return;

      state = _sequenceEngine.completeCurrentStep(state);
      if (!mounted) return;
      setState(() => _sequence = state);
      widget.journey.saveSequenceProgress(
        stepIndex: state.status == SequenceStatus.completed
            ? state.config.steps.length
            : state.stepIndex,
        completed: state.status == SequenceStatus.completed,
      );
    }

    if (!mounted) return;
    if (state.status == SequenceStatus.completed) {
      widget.journey.completeMissionObservation(missionNumber);
    }
  }

  Future<void> _waitWhileSequencePaused() async {
    while (_sequencePaused) {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Freezes the dwell clock while paused so resume continues the same beat.
  Future<void> _dwellIntentStep() async {
    var remaining = MissionScreen.intentStepDwell;
    while (remaining > Duration.zero) {
      if (!mounted) return;
      if (_sequencePaused) {
        await _waitWhileSequencePaused();
        if (!mounted) return;
        continue;
      }
      const slice = Duration(milliseconds: 50);
      final wait = remaining < slice ? remaining : slice;
      await Future<void>.delayed(wait);
      remaining -= wait;
    }
  }

  Future<void> _sendAssistantMessage() async {
    if (_assistantVm.isBusy) return;
    final input = _assistantController.text.trim();
    if (input.isEmpty) return;
    _assistantController.clear();

    // Focus mission BEFORE send so rebind does not dispose a mid-flight VM.
    final match = _packMatcher.match(input);
    final mission = match.missionNumber;
    if (mission != null) {
      widget.journey.startMissionFromIntent(mission);
      if (_mission.code != _missionCode) {
        _bindMission(recreateEngine: false);
      }
      _assistantVm.missionNumber = mission;
    }

    await _assistantVm.send(input);
    if (mounted) setState(() {});
  }

  void _onMicTap() {
    // Mic affordance: focus text input (STT package not in scope).
    _assistantFocus.requestFocus();
  }

  /// Hotspot "Tanya AI" — draft only; never auto-send / never sequenceCode.
  void _onHotspotAskAi(OrganelleHotspotContent content) {
    _assistantController.value = TextEditingValue(
      text: content.draftAiQuestion,
      selection: TextSelection.collapsed(
        offset: content.draftAiQuestion.length,
      ),
    );
    setState(() => _showLogbook = false);
    _assistantFocus.requestFocus();
  }

  /// Hotspot "Catat di Logbook" — open logbook and focus related field.
  void _onHotspotLogbook(OrganelleHotspotContent content) {
    setState(() => _showLogbook = true);
    final prompts = _mission.logbookPrompts;
    String? match;
    for (final prompt in prompts) {
      if (prompt.contains(content.logbookPromptSubstring) ||
          content.logbookPromptSubstring.contains(prompt)) {
        match = prompt;
        break;
      }
    }
    match ??= prompts.isNotEmpty ? prompts.first : null;
    if (match == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logbookFocusNodes[match]?.requestFocus();
    });
  }

  void _autosaveLogbook() {
    final entries = <String, String>{
      for (final entry in _logbookControllers.entries)
        entry.key: entry.value.text,
    };
    widget.journey.saveLogbook(entries);
  }

  @override
  Widget build(BuildContext context) {
    final mission = _mission;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _missionChrome(context),
            Expanded(child: _responsiveShell(context, mission: mission)),
          ],
        ),
      ),
    );
  }

  /// Compact mission chrome — title + chips + complete affordance only.
  /// Briefing / progress visuals already live in [JourneyProgressBar].
  Widget _missionChrome(BuildContext context) {
    final theme = Theme.of(context);
    final journey = widget.journey;
    final canComplete = journey.allMissionsCompleted || _sequenceCompleted;
    final titleText = journey.hasRunningMission || journey.labPlaced
        ? journey.activeMission.title
        : 'Scene 1 — Laboratorium Forensik Sel';
    final showBriefing = journey.hasRunningMission;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titleText,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (showBriefing)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                journey.activeMission.briefing,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= journey.missionCount; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: _MissionChip(
                    missionNumber: i,
                    label: _missionChipLabel(i),
                    status: journey.missionStatus(i),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                key: const Key('mission-logbook-toggle'),
                tooltip: 'Logbook',
                onPressed: () => setState(() => _showLogbook = !_showLogbook),
                icon: Icon(
                  _showLogbook
                      ? Icons.menu_book_rounded
                      : Icons.menu_book_outlined,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FilledButton(
            key: const Key('mission-complete'),
            onPressed: canComplete
                ? widget.journey.completeActiveMission
                : null,
            child: Text(
              journey.allMissionsCompleted
                  ? 'Ke Kesimpulan'
                  : 'Selesaikan Misi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveShell(
    BuildContext context, {
    required MissionContent mission,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final scenePanel = MissionScenePanel(
          key: ValueKey(
            'scene-${mission.code}-ar=${widget.journey.arSupported}',
          ),
          useAr: widget.journey.arSupported,
          missionCode: mission.code,
          stepCode: _sequence?.currentStep?.code,
          statusLabel: _statusLabel,
          stepLabel: _stepLabel,
          sequenceCompleted: _sequenceCompleted,
          sequencePaused: _sequencePaused,
          sceneEngine: _engine,
          onPlacementChanged: (placed) {
            unawaited(_onPlacementChanged(placed));
          },
          onRunStep: () {
            unawaited(_runStep());
          },
          onRequestLiveAr: widget.journey.arSupported ? null : _requestLiveAr,
          initiallyInspectedHotspots: {
            for (final raw in widget.journey.inspectedOrganelleHotspots)
              ?SampleAOrganelleHotspots.tryParse(raw),
          },
          onInspectedHotspotsChanged: (ids) {
            widget.journey.saveInspectedOrganelleHotspots(
              ids.map((e) => e.name),
            );
          },
          onHotspotAskAi: _onHotspotAskAi,
          onHotspotLogbook: _onHotspotLogbook,
        );

        final assistantPanel = Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 2,
          child: _assistantWorkspace(context),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 62, child: scenePanel),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(flex: 38, child: assistantPanel),
            ],
          );
        }

        return Column(
          children: [
            Expanded(flex: 65, child: scenePanel),
            const SizedBox(height: 4),
            Expanded(flex: 35, child: assistantPanel),
          ],
        );
      },
    );
  }

  Widget _assistantWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mission = _mission;
    final activeTab = _showLogbook ? _AssistantTab.logbook : _AssistantTab.chat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<_AssistantTab>(
            key: const Key('assistant-tab-bar'),
            segments: const [
              ButtonSegment<_AssistantTab>(
                value: _AssistantTab.chat,
                icon: Icon(Icons.smart_toy_outlined),
                label: Text('Asisten', key: Key('assistant-tab-chat')),
              ),
              ButtonSegment<_AssistantTab>(
                value: _AssistantTab.logbook,
                icon: Icon(Icons.menu_book_outlined),
                label: Text('Logbook', key: Key('assistant-tab-logbook')),
              ),
            ],
            selected: <_AssistantTab>{activeTab},
            onSelectionChanged: (selection) {
              final next = selection.single;
              if (next != activeTab) {
                setState(() => _showLogbook = next == _AssistantTab.logbook);
              }
            },
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: Key('assistant-tab-view-${activeTab.name}'),
            child: activeTab == _AssistantTab.chat
                ? _chatTab(context, theme: theme, scheme: scheme)
                : _logbookTab(mission: mission),
          ),
        ),
      ],
    );
  }

  Widget _chatTab(
    BuildContext context, {
    required ThemeData theme,
    required ColorScheme scheme,
  }) {
    final messages = _assistantVm.messages;
    final isBusy = _assistantVm.isBusy;
    final quickPrompts = switch (_missionNumber) {
      1 => const [
        'amati organel pada sampel a',
        'Apa dampak kerusakan kloroplas?',
      ],
      2 => const [
        'cairan Sampel B bocor?',
        'Apa fungsi membran sel?',
      ],
      3 => const [
        'Kenapa bentuk Sampel A tetap?',
        'Bandingkan Sampel A dan B',
      ],
      _ => const <String>[],
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 240;
        final inputRow = Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('mission-assistant-input'),
                controller: _assistantController,
                focusNode: _assistantFocus,
                textInputAction: TextInputAction.send,
                enabled: !isBusy,
                onSubmitted: (_) => _sendAssistantMessage(),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Tanya Asisten AI',
                  hintText: 'Contoh: cairan Sampel B bocor?',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Tanya Asisten AI mikrofon',
              child: IconButton.filledTonal(
                key: const Key('mission-assistant-mic'),
                tooltip: 'Tanya Asisten AI',
                onPressed: _onMicTap,
                icon: const Icon(Icons.mic_rounded),
              ),
            ),
            Semantics(
              button: true,
              label: 'Kirim pertanyaan',
              child: IconButton.filled(
                key: const Key('mission-assistant-send'),
                onPressed: isBusy ? null : _sendAssistantMessage,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        );

        final header = Row(
          children: [
            Text(
              'Asisten Investigasi',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(width: 6),
            if (isBusy) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 6),
              Text(
                'Menghubungi asisten…',
                key: const Key('assistant-busy-label'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Flexible(
                child: Text(
                  widget.journey.labPlaced
                      ? 'Intent → misi'
                      : 'Tempatkan lab dulu',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        );

        if (tight) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: ListView(
              children: [
                header,
                const SizedBox(height: 6),
                if (messages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      messages.last.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Tanya Asisten AI tentang Sampel A/B untuk memulai misi.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                inputRow,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (quickPrompts.isNotEmpty) ...[
                const SizedBox(height: 6),
                _quickPromptRow(
                  context,
                  prompts: quickPrompts,
                  onPick: _applyAssistantDraft,
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: messages.isEmpty
                    ? SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Tanya Asisten AI tentang Sampel A/B untuk '
                            'memulai misi.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isUser = message.author == ChatAuthor.user;
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                message.text,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isUser
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 6),
              inputRow,
            ],
          ),
        );
      },
    );
  }

  Widget _logbookTab({required MissionContent mission}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                'Logbook Misi',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: _logbookInline(mission: mission)),
        ],
      ),
    );
  }

  Widget _quickPromptRow(
    BuildContext context, {
    required List<String> prompts,
    required void Function(String prompt) onPick,
  }) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final prompt in prompts) ...[
            ActionChip(
              key: Key('assistant-quick-${prompt.hashCode}'),
              avatar: const Icon(Icons.flash_on_rounded, size: 14),
              label: Text(prompt, style: theme.textTheme.labelSmall),
              onPressed: () => onPick(prompt),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  void _applyAssistantDraft(String prompt) {
    _assistantController.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    setState(() => _showLogbook = false);
    _assistantFocus.requestFocus();
  }

  Widget _logbookInline({required MissionContent mission}) {
    final prompts = mission.logbookPrompts;
    return ListView(
      children: [
        for (var i = 0; i < prompts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              key: Key('logbook-field-$i'),
              controller: _logbookControllers[prompts[i]],
              focusNode: _logbookFocusNodes[prompts[i]],
              onChanged: (_) => _autosaveLogbook(),
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                isDense: true,
                labelText: prompts[i],
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }
}

enum _AssistantTab { chat, logbook }

String _missionChipLabel(int missionNumber) => switch (missionNumber) {
  1 || 2 => 'M$missionNumber Analisis',
  3 => 'M3 Perbedaan',
  _ => 'M$missionNumber',
};

class _MissionChip extends StatelessWidget {
  const _MissionChip({
    required this.missionNumber,
    required this.label,
    required this.status,
  });

  final int missionNumber;
  final String label;
  final MissionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      MissionStatus.locked => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      MissionStatus.available => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      MissionStatus.running => (scheme.primary, scheme.onPrimary),
      MissionStatus.completed => (scheme.tertiary, scheme.onTertiary),
    };
    return Container(
      key: Key('mission-chip-$missionNumber-${status.name}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
