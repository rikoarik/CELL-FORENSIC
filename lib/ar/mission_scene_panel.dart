import 'dart:async';
import 'dart:math' as math;

import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_capability_probe.dart';
import 'package:cell_forensic/ar/ar_lifecycle_controller.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/ar_scene_overlays.dart';
import 'package:cell_forensic/ar/ar_visual_director.dart';
import 'package:cell_forensic/ar/glb_asset_loader.dart';
import 'package:cell_forensic/ar/organelle_hotspot.dart';
import 'package:cell_forensic/ar/organelle_hotspot_layer.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart' hide ArPlacement;
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Surface-scan / placement states for the live AR path (E3-01).
enum ArScanPhase { scanning, planeReady, placed }

/// Investigation scene: real AR camera when [useAr] is true, otherwise an
/// interactive GLB [ModelViewer] (FR-011 / FR-124). Sequence controls stay in
/// the parent so misi / logbook flow is identical in both modes.
///
/// Commands go through [sceneEngine] so Fake/Live engines are not orphaned
/// (FR-121 / E3-02). Tracking loss pauses sequence advancement in the parent
/// via [ArSceneEngine.isPaused] (E3-07 / FR-025).
///
/// E11: after plane+place, the same [ARPlaneAnchor] is kept across M1–3 step
/// swaps. `model_viewer_plus` is FALLBACK ONLY (unsupported / init failure) —
/// never opened as a separate page mid-sequence on a healthy ARCore session.
class MissionScenePanel extends StatefulWidget {
  const MissionScenePanel({
    required this.useAr,
    required this.missionCode,
    required this.statusLabel,
    required this.stepLabel,
    required this.sequenceCompleted,
    required this.onRunStep,
    required this.sceneEngine,
    this.stepCode,
    this.sequencePaused = false,
    this.onPlacementChanged,
    this.onRequestLiveAr,
    this.onHotspotAskAi,
    this.onHotspotLogbook,
    this.initiallyInspectedHotspots,
    this.onInspectedHotspotsChanged,
    super.key,
  });

  final bool useAr;
  final String missionCode;
  final String? stepCode;
  final String statusLabel;
  final String stepLabel;
  final bool sequenceCompleted;
  final bool sequencePaused;
  final VoidCallback onRunStep;
  final ArSceneEngine sceneEngine;
  final ValueChanged<bool>? onPlacementChanged;

  /// Optional upgrade from Mode 3D → live AR (same group/session).
  final VoidCallback? onRequestLiveAr;

  /// Draft-only AI question from an organelle popup (never auto-sent).
  final ValueChanged<OrganelleHotspotContent>? onHotspotAskAi;

  /// Focus related logbook field from an organelle popup.
  final ValueChanged<OrganelleHotspotContent>? onHotspotLogbook;

  /// Inspected ids restored from session snapshot (optional).
  final Set<OrganelleHotspotId>? initiallyInspectedHotspots;

  /// Persist inspected set when it changes (optional).
  final ValueChanged<Set<OrganelleHotspotId>>? onInspectedHotspotsChanged;

  /// Widget tests cannot host AR/WebView platform views.
  @visibleForTesting
  static bool debugUsePlaceholderScene = false;

  @override
  State<MissionScenePanel> createState() => _MissionScenePanelState();
}

/// Live mesh scale = base × user gesture × sequence [ArSceneVisualState.nodeScale].
///
/// Pure helper so Wave 5 tests can assert director zooms reach the camera path
/// without hosting `ARNode` platform views.
@visibleForTesting
double combineLiveNodeScale({
  required double baseScale,
  required double gestureScale,
  ArVec3? sequenceScale,
}) {
  final seq = sequenceScale ?? ArVec3.one;
  // Directors store uniform XYZ scales; average keeps non-uniform future-safe.
  final seqFactor = (seq.x + seq.y + seq.z) / 3.0;
  return baseScale * gestureScale * seqFactor;
}

class _MissionScenePanelState extends State<MissionScenePanel>
    with WidgetsBindingObserver {
  static const _baseScale = 0.08;
  static const _director = ArVisualDirector();

  /// Keeps the AR platform view identity stable across parent rebuilds.
  final GlobalKey _arViewKey = GlobalKey(debugLabel: 'mission-live-ar');

  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchors;
  ARPlaneAnchor? _placedAnchor;
  ARNode? _labTableNode;
  ARNode? _placedNode;
  ARNode? _secondaryNode;
  String? _labTableAssetPath;
  String? _placedAssetPath;
  String? _secondaryAssetPath;
  String? _arError;
  ArScanPhase _scanPhase = ArScanPhase.scanning;
  bool _fallbackReady = false;

  /// Soft fallback only after fatal live-AR init failure (E11-A).
  bool _liveInitFailed = false;
  late final ArLifecycleController _lifecycle;
  StreamSubscription<ArSceneEvent>? _visualSub;
  ArCapabilityResult? _capability;

  double _gestureScale = 1;
  double _gestureRotationY = 0;
  String? _selectedStructure;
  late final OrganelleHotspotController _hotspots;

  String get _activeAsset {
    final override = widget.sceneEngine.visualState.activeModelPath;
    if (override != null && override.isNotEmpty) return override;
    final stepModel = ArAssetRegistry.modelForStep(
      widget.missionCode,
      widget.stepCode,
    );
    return stepModel ??
        ArAssetRegistry.primaryModelForMission(widget.missionCode);
  }

  bool get _wantsLiveAr => widget.useAr && !_liveInitFailed;

  bool get _canRunStep {
    if (widget.sequenceCompleted || widget.sequencePaused) return false;
    if (_wantsLiveAr) return _scanPhase == ArScanPhase.placed;
    return _fallbackReady;
  }

  @override
  void initState() {
    super.initState();
    _hotspots = OrganelleHotspotController(
      initiallyInspected: widget.initiallyInspectedHotspots,
    );
    _hotspots.addListener(_onHotspotControllerChanged);
    _lifecycle = ArLifecycleController(widget.sceneEngine);
    WidgetsBinding.instance.addObserver(this);
    _visualSub = widget.sceneEngine.events.listen(_onEngineEvent);
    debugPrint(
      'MissionScenePanel path='
      '${_wantsLiveAr ? 'live_ar' : 'model_viewer'} '
      'useAr=${widget.useAr} liveInitFailed=$_liveInitFailed',
    );
    if (!_wantsLiveAr) {
      // Fallback 3D has full mission parity without plane scan (E3-08).
      _fallbackReady = true;
      unawaited(_probeCapabilityForUpgrade());
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await widget.sceneEngine.place(const ArPlacement(x: 0, y: 0, z: 0));
        if (mounted) widget.onPlacementChanged?.call(true);
        // Scene 1 base only — do not auto-start Mission 1 sequence (GAP-1).
        await _finalizePlacement();
      });
    }
  }

  void _onHotspotControllerChanged() {
    widget.onInspectedHotspotsChanged?.call(_hotspots.inspectedIds);
    final selected = _hotspots.selectedId;
    if (selected != null) {
      final content = SampleAOrganelleHotspots.contentFor(selected);
      unawaited(
        widget.sceneEngine.setMaterialHighlight(
          content.nodeId,
          enabled: true,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  void _enableHotspots() {
    _hotspots.setEnabled(true);
  }

  Future<void> _probeCapabilityForUpgrade() async {
    final result = await ArCapabilityProbe().probe();
    if (!mounted) return;
    setState(() => _capability = result);
  }

  void _onEngineEvent(ArSceneEvent event) {
    if (!mounted) return;
    if (event.type == ArSceneEventType.visualChanged ||
        event.type == ArSceneEventType.resetCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_syncNodesFromVisualState());
        setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle.handleAppLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      // Fallback 3D has no ARCore session — confirm healthy tracking so the
      // sequence can continue. Live AR waits for plane / place / debug OK.
      if (!_wantsLiveAr) {
        _lifecycle.confirmRelocalized();
      } else if (_scanPhase == ArScanPhase.placed) {
        // Already placed: plane callbacks after resume count as relocalization.
        // Keep gated until onPlaneDetected / place / debug OK fires.
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MissionScenePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sceneEngine != widget.sceneEngine) {
      _visualSub?.cancel();
      _visualSub = widget.sceneEngine.events.listen(_onEngineEvent);
    }
    if (oldWidget.missionCode != widget.missionCode ||
        oldWidget.stepCode != widget.stepCode) {
      unawaited(_applyStepVisuals());
    }
    // Wave 5: re-apply current step visuals when tracking recovers mid-step.
    if (oldWidget.sequencePaused &&
        !widget.sequencePaused &&
        widget.stepCode != null) {
      unawaited(_applyStepVisuals());
    }
  }

  Future<void> _applyStepVisuals() async {
    final step = widget.stepCode;
    if (step == null) return;
    if (widget.sequencePaused) return;
    await _director.applySequenceStep(
      widget.sceneEngine,
      missionCode: widget.missionCode,
      stepCode: step,
    );
    await _syncNodesFromVisualState();
  }

  /// Scene 1 after plane tap / fallback ready: Meja Lab + Sample A + Sample B.
  /// Does not advance the mission sequence (GAP-1).
  Future<void> _finalizePlacement() async {
    await widget.sceneEngine.initLabScene(
      labTableModelPath: ArAssetRegistry.mejaLab,
      sampleAModelPath: ArAssetRegistry.sampleA,
      sampleBModelPath: ArAssetRegistry.sampleB,
    );
    await _syncNodesFromVisualState();
    // Mid-mission restore only: re-apply an already-active step. Fresh
    // placement has stepCode == null until "Jalankan Langkah".
    if (widget.stepCode != null) {
      await _applyStepVisuals();
    }
    // Hotspots only after group + placement (never before).
    if (mounted) _enableHotspots();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hotspots.removeListener(_onHotspotControllerChanged);
    _hotspots.dispose();
    _visualSub?.cancel();
    _session?.dispose();
    super.dispose();
  }

  Widget _buildHotspotLayer({required bool dualSamples}) {
    return OrganelleHotspotLayer(
      controller: _hotspots,
      dualSamples: dualSamples,
    );
  }

  Widget _buildHotspotSheet() {
    return OrganelleObservationSheet(
      controller: _hotspots,
      onAskAi: widget.onHotspotAskAi,
      onLogbook: widget.onHotspotLogbook,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = widget.sceneEngine.visualState;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight;
        final compactHeight = boundedHeight && constraints.maxHeight < 560;
        final sceneFlex = compactHeight ? 6 : 7;
        final detailFlex = compactHeight ? 4 : 3;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: sceneFlex,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MissionScenePanel.debugUsePlaceholderScene
                          ? _buildPlaceholder(theme)
                          : (_wantsLiveAr
                                ? _buildArView(visual)
                                : _buildModelViewer()),
                      _buildTopHud(theme),
                      _buildBottomControls(theme),
                    ],
                  ),
                ),
                Flexible(
                  flex: detailFlex,
                  child: _buildDetailPane(theme, compactHeight: compactHeight),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHud(ThemeData theme) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Material(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ArAssetRegistry.modeLabel(useAr: _wantsLiveAr),
                          key: const Key('mission-mode-label'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!_wantsLiveAr &&
                          widget.onRequestLiveAr != null &&
                          _capability?.supported == true)
                        OutlinedButton.icon(
                          key: const Key('mission-activate-live-ar'),
                          onPressed: widget.onRequestLiveAr,
                          icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                          label: const Text('Mode AR'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    label: 'Status scene: ${widget.statusLabel}',
                    child: Text(
                      'Status: ${widget.statusLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.stepLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  if (_wantsLiveAr) ...[
                    const SizedBox(height: 2),
                    Text(
                      _scanHint,
                      key: const Key('mission-scan-hint'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (_liveInitFailed) ...[
                    const SizedBox(height: 6),
                    Text(
                      'AR gagal diinisialisasi — memakai mode 3D '
                      '(fallback). Sequence tetap sama.',
                      key: const Key('mission-fallback-banner'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.errorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (widget.sequencePaused) ...[
                    const SizedBox(height: 6),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Pelacakan AR hilang — sequence dijeda. Gerakkan '
                        'perangkat perlahan hingga tracking pulih.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.errorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_arError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _arError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.errorContainer,
                      ),
                    ),
                  ],
                  if (_selectedStructure != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Struktur dipilih: $_selectedStructure',
                      key: const Key('mission-selected-structure'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      enabled: _canRunStep,
                      label: 'Jalankan langkah scene berikutnya',
                      child: FilledButton.tonal(
                        key: const Key('mission-run-step'),
                        onPressed: _canRunStep ? widget.onRunStep : null,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Jalankan Langkah'),
                      ),
                    ),
                  ),
                  if (_wantsLiveAr) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Reset penempatan scene AR',
                      child: OutlinedButton(
                        key: const Key('mission-reset-scene'),
                        onPressed: _resetScene,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPane(ThemeData theme, {required bool compactHeight}) {
    return Container(
      color: theme.colorScheme.surface,
      child: DefaultTabController(
        length: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: compactHeight ? 180 : 220,
                    ),
                    child: SingleChildScrollView(
                      child: _buildHotspotSheet(),
                    ),
                  ),
                  Text(
                    _wantsLiveAr
                        ? 'Arahkan kamera ke permukaan datar hingga bidang '
                              'terdeteksi, lalu ketuk untuk menempatkan Meja '
                              'Laboratorium beserta Sampel A dan Sampel B.'
                        : 'Seret untuk memutar, cubit untuk zoom. Setelah meja '
                              'dan kedua sampel tampil, jalankan langkah '
                              'sequence untuk mengubah fokus.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (MissionScenePanel.debugUsePlaceholderScene &&
                      widget.useAr) ...[
                    const SizedBox(height: 8),
                    _buildDebugArControls(),
                  ],
                  if (_scanPhase == ArScanPhase.placed || !_wantsLiveAr) ...[
                    const SizedBox(height: 8),
                    _buildGestureControls(theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton(
            key: const Key('mission-gesture-pinch-out'),
            onPressed: widget.sequencePaused
                ? null
                : () => _adjustScale(1.15),
            child: const Text('Perbesar'),
          ),
          TextButton(
            key: const Key('mission-gesture-pinch-in'),
            onPressed: widget.sequencePaused
                ? null
                : () => _adjustScale(1 / 1.15),
            child: const Text('Perkecil'),
          ),
          TextButton(
            key: const Key('mission-gesture-rotate'),
            onPressed: widget.sequencePaused ? null : () => _nudgeRotation(),
            child: const Text('Putar'),
          ),
          TextButton(
            key: const Key('mission-gesture-reset-transform'),
            onPressed: widget.sequencePaused ? null : _resetTransform,
            child: const Text('Kembali ke posisi awal'),
          ),
          TextButton(
            key: const Key('mission-tap-chloroplast'),
            onPressed: widget.sequencePaused
                ? null
                : () => _selectStructure('kloroplas'),
            child: const Text('Ketuk kloroplas'),
          ),
          TextButton(
            key: const Key('mission-tap-vacuole'),
            onPressed: widget.sequencePaused
                ? null
                : () => _selectStructure('vakuola'),
            child: const Text('Ketuk vakuola'),
          ),
          TextButton(
            key: const Key('mission-tap-membrane'),
            onPressed: widget.sequencePaused
                ? null
                : () => _selectStructure('membran'),
            child: const Text('Ketuk membran'),
          ),
          if (_wantsLiveAr && _scanPhase == ArScanPhase.placed)
            Text(
              'Ketuk bidang lagi untuk reposisi (anchor baru).',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _adjustScale(double factor) async {
    _gestureScale = (_gestureScale * factor).clamp(0.4, 2.5);
    await widget.sceneEngine.setUserTransform(scale: _gestureScale);
    await _applyUserTransformToNodes();
    if (mounted) setState(() {});
  }

  Future<void> _nudgeRotation() async {
    _gestureRotationY += math.pi / 8;
    await widget.sceneEngine.setUserTransform(rotationY: _gestureRotationY);
    await _applyUserTransformToNodes();
    if (mounted) setState(() {});
  }

  Future<void> _resetTransform() async {
    _gestureScale = 1;
    _gestureRotationY = 0;
    await widget.sceneEngine.resetTransform();
    await _applyUserTransformToNodes();
    if (mounted) setState(() {});
  }

  void _selectStructure(String name) {
    setState(() => _selectedStructure = name);
    if (name == 'kloroplas') {
      // Debug affordance shares the observation hotspot path (no sequence).
      if (_hotspots.enabled) {
        _hotspots.select(OrganelleHotspotId.chloroplast);
      } else {
        unawaited(
          widget.sceneEngine.setMaterialHighlight(
            ArNodeIds.chloroplast,
            enabled: true,
          ),
        );
      }
    } else if (name == 'vakuola') {
      if (_hotspots.enabled) {
        _hotspots.select(OrganelleHotspotId.vacuole);
      } else {
        unawaited(
          widget.sceneEngine.setMaterialHighlight(
            ArNodeIds.vacuole,
            enabled: true,
          ),
        );
      }
    } else if (name == 'membran') {
      unawaited(
        widget.sceneEngine.setMaterialHighlight(
          ArNodeIds.membrane,
          enabled: true,
        ),
      );
    }
  }

  String get _scanHint {
    return switch (_scanPhase) {
      ArScanPhase.scanning =>
        'Pindai permukaan meja untuk memunculkan Laboratorium Forensik Sel.',
      ArScanPhase.planeReady => 'Bidang terdeteksi — ketuk untuk menempatkan.',
      ArScanPhase.placed =>
        'Meja Laboratorium + Sampel A & B ditempatkan. Jalankan langkah untuk memulai misi.',
    };
  }

  Widget _buildPlaceholder(ThemeData theme) {
    final visual = widget.sceneEngine.visualState;
    return ColoredBox(
      color: const Color(0xFF1A1F24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Text(
              'Scene placeholder (test)',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ArSceneOverlayLayer(
            effect: visual.overlay,
            highlightTarget: visual.highlightTarget,
            opacity: visual.opacity,
            dualSamples: visual.secondaryModelPath != null,
          ),
          _buildHotspotLayer(
            dualSamples: visual.secondaryModelPath != null,
          ),
          if (widget.sequencePaused)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  'Tracking hilang',
                  key: const Key('mission-tracking-lost'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (_wantsLiveAr && _scanPhase != ArScanPhase.placed)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _scanHint,
                    style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebugArControls() {
    return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton(
            key: const Key('mission-debug-plane'),
            onPressed: () {
              setState(() => _scanPhase = ArScanPhase.planeReady);
            },
            child: const Text('Debug Plane'),
          ),
          TextButton(
            key: const Key('mission-debug-place'),
            onPressed: () => _debugPlace(),
            child: const Text('Debug Place'),
          ),
          TextButton(
            key: const Key('mission-debug-tracking-lost'),
            onPressed: () =>
                widget.sceneEngine.updateTracking(ArTrackingState.lost),
            child: const Text('Debug Lost'),
          ),
          TextButton(
            key: const Key('mission-debug-tracking-ok'),
            onPressed: () {
              _lifecycle.confirmRelocalized();
              widget.sceneEngine.updateTracking(ArTrackingState.tracking);
            },
            child: const Text('Debug OK'),
          ),
          TextButton(
            key: const Key('mission-debug-force-fallback'),
            onPressed: () {
              // Only for tests: simulate unsupported / init failure.
              setState(() {
                _liveInitFailed = true;
                _fallbackReady = true;
              });
              widget.onPlacementChanged?.call(true);
              unawaited(() async {
                await widget.sceneEngine.place(
                  const ArPlacement(x: 0, y: 0, z: 0),
                );
                await _finalizePlacement();
              }());
            },
            child: const Text('Debug Fallback'),
          ),
        ],
      );
  }

  Future<void> _debugPlace() async {
    setState(() {
      _scanPhase = ArScanPhase.placed;
      _arError = null;
      _liveInitFailed = false;
    });
    widget.onPlacementChanged?.call(true);
    await widget.sceneEngine.place(const ArPlacement(x: 0, y: 0, z: -1));
    await _finalizePlacement();
  }

  Widget _buildModelViewer() {
    final visual = widget.sceneEngine.visualState;
    final secondary = visual.secondaryModelPath;
    final showLabPair = secondary != null && secondary.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showLabPair)
          Row(
            children: [
              Expanded(
                child: ModelViewer(
                  key: ValueKey('mv-a-${widget.missionCode}-$_activeAsset'),
                  src: _activeAsset,
                  alt: 'Sampel A — sel tumbuhan',
                  ar: false,
                  autoRotate: true,
                  cameraControls: true,
                  disableZoom: false,
                  cameraOrbit: ArAssetRegistry.cameraOrbitForStep(
                    widget.stepCode,
                  ),
                  backgroundColor: const Color(0xFF1A1F24),
                  loading: Loading.eager,
                  relatedCss: 'body { margin: 0; background: #1A1F24; }',
                ),
              ),
              Expanded(
                child: ModelViewer(
                  key: ValueKey('mv-b-${widget.missionCode}-$secondary'),
                  src: secondary,
                  alt: 'Sampel B — sel hewan',
                  ar: false,
                  autoRotate: true,
                  cameraControls: true,
                  disableZoom: false,
                  cameraOrbit: ArAssetRegistry.cameraOrbitForStep(
                    widget.stepCode,
                  ),
                  backgroundColor: const Color(0xFF1A1F24),
                  loading: Loading.eager,
                  relatedCss: 'body { margin: 0; background: #1A1F24; }',
                ),
              ),
            ],
          )
        else
          ModelViewer(
            // Keep viewer mounted across step changes when possible — key by
            // mission only so sequence does not feel like a new page.
            key: ValueKey('mv-${widget.missionCode}-$_activeAsset'),
            src: _activeAsset,
            alt: 'Model 3D misi ${widget.missionCode}',
            ar: false,
            autoRotate: true,
            cameraControls: true,
            disableZoom: false,
            cameraOrbit: ArAssetRegistry.cameraOrbitForStep(widget.stepCode),
            backgroundColor: const Color(0xFF1A1F24),
            loading: Loading.eager,
            relatedCss: 'body { margin: 0; background: #1A1F24; }',
          ),
        if (visual.labTableModelPath != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Meja Laboratorium',
                key: const Key('mission-lab-table-label'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ArSceneOverlayLayer(
          effect: visual.overlay,
          highlightTarget: visual.highlightTarget,
          opacity: visual.opacity,
          dualSamples: visual.secondaryModelPath != null,
        ),
        _buildHotspotLayer(
          dualSamples: visual.secondaryModelPath != null,
        ),
      ],
    );
  }

  Widget _buildArView(ArSceneVisualState visual) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ARView(
          key: _arViewKey,
          onARViewCreated: _onArViewCreated,
          planeDetectionConfig: PlaneDetectionConfig.horizontal,
        ),
        if (_scanPhase == ArScanPhase.placed) ...[
          ArSceneOverlayLayer(
            effect: visual.overlay,
            highlightTarget: visual.highlightTarget,
            opacity: visual.opacity,
            dualSamples: visual.secondaryModelPath != null,
          ),
          _buildHotspotLayer(
            dualSamples: visual.secondaryModelPath != null,
          ),
        ],
        if (_scanPhase != ArScanPhase.placed)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              key: const Key('mission-scan-hint'),
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _scanHint,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (widget.sequencePaused)
          ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Tracking hilang\nGerakkan perangkat perlahan',
                  key: const Key('mission-tracking-lost'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onArViewCreated(
    ARSessionManager session,
    ARObjectManager objects,
    ARAnchorManager anchors,
    ARLocationManager location,
  ) {
    // If we already placed on this session, do not re-init (avoid rebuild reset).
    if (_session != null && _scanPhase == ArScanPhase.placed) {
      return;
    }

    _session = session;
    _objects = objects;
    _anchors = anchors;

    // Assign late handlers before onInitialize — native plane callbacks can
    // fire during init and otherwise throw LateInitializationError.
    session.onPlaneOrPointTap = _onPlaneTapped;
    session.onPlaneDetected = (count) {
      if (!mounted) return;
      if (count > 0 && _lifecycle.awaitingRelocalization) {
        _lifecycle.confirmRelocalized();
      }
      if (_scanPhase == ArScanPhase.placed) return;
      if (count > 0) {
        setState(() => _scanPhase = ArScanPhase.planeReady);
      }
    };
    session.onError = (message) {
      final lower = message.toLowerCase();
      final looksLikeTrackingLoss =
          lower.contains('track') ||
          lower.contains('relocal') ||
          lower.contains('limited');
      if (looksLikeTrackingLoss) {
        widget.sceneEngine.updateTracking(ArTrackingState.lost);
        if (mounted) setState(() => _arError = message);
        return;
      }

      final fatal = isFatalLiveArInitFailure(message);
      if (fatal && _scanPhase != ArScanPhase.placed) {
        // Soft fallback — only when live session never successfully placed.
        debugPrint('MissionScenePanel soft-fallback: $message');
        if (mounted) {
          setState(() {
            _liveInitFailed = true;
            _fallbackReady = true;
            _arError = message;
          });
          widget.onPlacementChanged?.call(true);
          unawaited(() async {
            await widget.sceneEngine.place(
              const ArPlacement(x: 0, y: 0, z: 0),
            );
            await _finalizePlacement();
          }());
        }
        return;
      }
      if (mounted) setState(() => _arError = message);
    };

    try {
      session.onInitialize(
        showFeaturePoints: false,
        showPlanes: true,
        showWorldOrigin: false,
        handleTaps: true,
      );
      objects.onInitialize();
    } catch (error) {
      if (_scanPhase != ArScanPhase.placed && mounted) {
        setState(() {
          _liveInitFailed = true;
          _fallbackReady = true;
          _arError = 'Error AR: $error';
        });
        widget.onPlacementChanged?.call(true);
        unawaited(() async {
          await widget.sceneEngine.place(const ArPlacement(x: 0, y: 0, z: 0));
          await _finalizePlacement();
        }());
      }
    }
  }

  Future<void> _onPlaneTapped(List<ARHitTestResult> hits) async {
    if (widget.sequencePaused) return;

    ARHitTestResult? planeHit;
    for (final hit in hits) {
      if (hit.type == ARHitTestResultType.plane) {
        planeHit = hit;
        break;
      }
    }
    if (planeHit == null) return;

    final session = _session;
    final objects = _objects;
    final anchors = _anchors;
    if (session == null || objects == null || anchors == null) return;

    try {
      // Reposition: replace anchor only when user taps again after placed.
      // Sequence step changes never call this path.
      if (_placedAnchor != null) {
        _removeAllSceneNodes(objects);
        anchors.removeAnchor(_placedAnchor!);
        _placedAnchor = null;
        _labTableNode = null;
        _placedNode = null;
        _secondaryNode = null;
        _labTableAssetPath = null;
        _placedAssetPath = null;
        _secondaryAssetPath = null;
      }

      final anchor = ARPlaneAnchor(transformation: planeHit.worldTransform);
      final added = await anchors.addAnchor(anchor);
      if (added != true) {
        setState(() => _arError = 'Gagal menempatkan anchor AR.');
        return;
      }

      final translation = planeHit.worldTransform.getTranslation();
      await widget.sceneEngine.place(
        ArPlacement(x: translation.x, y: translation.y, z: translation.z),
      );

      // Successful place implies tracking is healthy again.
      _lifecycle.confirmRelocalized();
      widget.sceneEngine.updateTracking(ArTrackingState.tracking);

      if (!mounted) return;
      setState(() {
        _placedAnchor = anchor;
        _scanPhase = ArScanPhase.placed;
        _liveInitFailed = false;
        _arError = null;
      });
      widget.onPlacementChanged?.call(true);
      // Meja + Sampel A + Sampel B; do not auto-run Mission 1 (GAP-1).
      await _finalizePlacement();
      if (_placedNode == null && mounted) {
        setState(() => _arError = 'Gagal memuat model GLB ke scene AR.');
      }
    } catch (error) {
      setState(() => _arError = 'Error AR: $error');
    }
  }

  void _removeAllSceneNodes(ARObjectManager objects) {
    if (_labTableNode != null) {
      objects.removeNode(_labTableNode!);
    }
    if (_placedNode != null) {
      objects.removeNode(_placedNode!);
    }
    if (_secondaryNode != null) {
      objects.removeNode(_secondaryNode!);
    }
  }

  Future<ARNode> _createNodeForAsset(
    String assetPath, {
    Vector3? position,
    String? nodeId,
  }) async {
    final fileName = await GlbAssetLoader.ensureOnDisk(assetPath);
    final scale = _liveScaleFor(nodeId);
    return ARNode(
      type: NodeType.fileSystemAppFolderGLB,
      uri: fileName,
      scale: scale,
      position: position ?? Vector3.zero(),
      rotation: Vector4(0, 1, 0, _gestureRotationY),
    );
  }

  /// Resolves sequence [nodeScale] for a live node (gesture kept separate).
  ArVec3? _sequenceScaleFor(String? nodeId) {
    if (nodeId == null) return null;
    final scales = widget.sceneEngine.visualState.nodeScale;
    final direct = scales[nodeId];
    if (direct != null) return direct;
    // Primary node may be keyed as sampleA during M1 focus.
    if (nodeId == ArNodeIds.primary) {
      return scales[ArNodeIds.sampleA];
    }
    if (nodeId == ArNodeIds.sampleA) {
      return scales[ArNodeIds.primary];
    }
    return null;
  }

  Vector3 _liveScaleFor(String? nodeId) {
    final seq = _sequenceScaleFor(nodeId) ?? ArVec3.one;
    // Prefer component-wise so non-uniform director scales still apply.
    return Vector3(
      _baseScale * _gestureScale * seq.x,
      _baseScale * _gestureScale * seq.y,
      _baseScale * _gestureScale * seq.z,
    );
  }

  Future<void> _syncNodesFromVisualState() async {
    if (!_wantsLiveAr || _scanPhase != ArScanPhase.placed) return;
    final objects = _objects;
    final anchor = _placedAnchor;
    if (objects == null || anchor == null) return;
    if (widget.sequencePaused) return;

    final visual = widget.sceneEngine.visualState;
    _gestureScale = visual.userScale;
    _gestureRotationY = visual.userRotationY;

    final labPath = visual.labTableModelPath;
    final labVisible = visual.visibleNodes[ArNodeIds.labTable] ?? true;
    if (labPath == null || !labVisible) {
      if (_labTableNode != null) {
        objects.removeNode(_labTableNode!);
        _labTableNode = null;
        _labTableAssetPath = null;
      }
    } else if (_labTableAssetPath != labPath || _labTableNode == null) {
      if (_labTableNode != null) {
        objects.removeNode(_labTableNode!);
      }
      final labPos = _vecFromAr(
        visual.nodePosition[ArNodeIds.labTable] ?? ArVec3.zero,
      );
      final labNode = await _createNodeForAsset(
        labPath,
        position: labPos,
        nodeId: ArNodeIds.labTable,
      );
      final ok = await objects.addNode(labNode, planeAnchor: anchor);
      if (ok == true && mounted) {
        _labTableNode = labNode;
        _labTableAssetPath = labPath;
      }
    }

    final desiredPrimary = visual.activeModelPath ?? _activeAsset;
    if (_placedAssetPath != desiredPrimary || _placedNode == null) {
      await _replacePrimaryModel(desiredPrimary);
    } else {
      await _applyUserTransformToNodes();
    }

    final secondary = visual.secondaryModelPath;
    if (secondary == null) {
      if (_secondaryNode != null) {
        objects.removeNode(_secondaryNode!);
        _secondaryNode = null;
        _secondaryAssetPath = null;
      }
    } else if (_secondaryAssetPath != secondary || _secondaryNode == null) {
      if (_secondaryNode != null) {
        objects.removeNode(_secondaryNode!);
      }
      final sampleBPos =
          visual.nodePosition[ArNodeIds.sampleB] ??
          ArVec3(visual.secondaryOffsetX, 0.03, 0);
      final node = await _createNodeForAsset(
        secondary,
        position: _vecFromAr(sampleBPos),
        nodeId: ArNodeIds.sampleB,
      );
      final ok = await objects.addNode(node, planeAnchor: anchor);
      if (ok == true && mounted) {
        _secondaryNode = node;
        _secondaryAssetPath = secondary;
      }
    } else {
      await _applyUserTransformToNodes();
    }

    if (mounted) setState(() {});
  }

  Vector3 _vecFromAr(ArVec3 v) => Vector3(v.x, v.y, v.z);

  Future<void> _replacePrimaryModel(String assetPath) async {
    final objects = _objects;
    final anchor = _placedAnchor;
    final node = _placedNode;
    if (objects == null || anchor == null) return;
    // Keep the same plane anchor — only swap the GLB node (E11-B).
    if (node != null) {
      objects.removeNode(node);
    }
    try {
      final visual = widget.sceneEngine.visualState;
      final pos =
          visual.nodePosition[ArNodeIds.primary] ??
          visual.nodePosition[ArNodeIds.sampleA] ??
          ArVec3.zero;
      final next = await _createNodeForAsset(
        assetPath,
        position: _vecFromAr(pos),
        nodeId: ArNodeIds.primary,
      );
      final ok = await objects.addNode(next, planeAnchor: anchor);
      if (ok == true && mounted) {
        setState(() {
          _placedNode = next;
          _placedAssetPath = assetPath;
          _arError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _arError = 'Gagal mengganti model: $error');
    }
  }

  Future<void> _applyUserTransformToNodes() async {
    final visual = widget.sceneEngine.visualState;
    final lab = _labTableNode;
    if (lab != null) {
      lab.scale = _liveScaleFor(ArNodeIds.labTable);
      lab.eulerAngles = Vector3(0, _gestureRotationY, 0);
      final labPos = visual.nodePosition[ArNodeIds.labTable] ?? ArVec3.zero;
      lab.position = _vecFromAr(labPos);
    }
    final primary = _placedNode;
    if (primary != null) {
      primary.scale = _liveScaleFor(ArNodeIds.primary);
      primary.eulerAngles = Vector3(0, _gestureRotationY, 0);
      final primaryPos =
          visual.nodePosition[ArNodeIds.primary] ??
          visual.nodePosition[ArNodeIds.sampleA];
      if (primaryPos != null) {
        primary.position = _vecFromAr(primaryPos);
      }
    }
    final secondary = _secondaryNode;
    if (secondary != null) {
      secondary.scale = _liveScaleFor(ArNodeIds.sampleB);
      secondary.eulerAngles = Vector3(0, _gestureRotationY, 0);
      final sampleBPos =
          visual.nodePosition[ArNodeIds.sampleB] ??
          ArVec3(visual.secondaryOffsetX, 0.03, 0);
      secondary.position = _vecFromAr(sampleBPos);
    }
  }

  Future<void> _resetScene() async {
    final objects = _objects;
    final anchors = _anchors;
    final anchor = _placedAnchor;
    if (objects != null) {
      _removeAllSceneNodes(objects);
    }
    if (anchors != null && anchor != null) {
      anchors.removeAnchor(anchor);
    }
    await widget.sceneEngine.reset();
    widget.sceneEngine.updateTracking(ArTrackingState.tracking);
    if (!mounted) return;
    _hotspots.onResetScan();
    setState(() {
      _placedAnchor = null;
      _labTableNode = null;
      _placedNode = null;
      _secondaryNode = null;
      _labTableAssetPath = null;
      _placedAssetPath = null;
      _secondaryAssetPath = null;
      _scanPhase = ArScanPhase.scanning;
      _arError = null;
      _gestureScale = 1;
      _gestureRotationY = 0;
      _selectedStructure = null;
    });
    widget.onPlacementChanged?.call(false);
  }
}
