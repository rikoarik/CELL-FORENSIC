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
import 'package:flutter/foundation.dart';
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
  /// Cell `scaleToUnits` (legacy solo-organelle meshes). Merged scene GLBs use
  /// [_labTableBaseScale] because they include the full lab desk footprint.
  static const _baseScale = 0.20;
  /// Desk footprint (SceneView `scaleToUnits`). Merged `scene-*.glb` author size
  /// ≈ meja 2.06×0.90×1.27 → at 1.6 m the tabletop sits ≈ above the plane.
  static const _labTableBaseScale = 1.60;
  /// TempatUji author 0.13×0.02×0.13 → ~0.22 m diameter on the tabletop.
  static const _tempatUjiBaseScale = 0.22;
  /// Half-gap between Sampel A / B tray centers on the 1.6 m desk.
  static const _sampleOffsetX = 0.12;
  static const _director = ArVisualDirector();

  /// Keeps the AR platform view identity stable across parent rebuilds.
  final GlobalKey _arViewKey = GlobalKey(debugLabel: 'mission-live-ar');

  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchors;
  ARPlaneAnchor? _placedAnchor;
  ARNode? _labTableNode;
  ARNode? _tempatUjiANode;
  ARNode? _tempatUjiBNode;
  ARNode? _placedNode;
  ARNode? _secondaryNode;
  String? _labTableAssetPath;
  String? _tempatUjiAssetPath;
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
  late final OrganelleHotspotController _hotspots;
  Timer? _introDismissTimer;

  String get _activeAsset {
    final override = widget.sceneEngine.visualState.activeModelPath;
    var path = (override != null && override.isNotEmpty)
        ? override
        : (ArAssetRegistry.modelForStep(widget.missionCode, widget.stepCode) ??
              ArAssetRegistry.primaryModelForMission(widget.missionCode));
    // Mode 3D: prefer hi-fi export when the logical plant cell is active.
    if (!_wantsLiveAr && path == ArAssetRegistry.sampleA) {
      path = ArAssetRegistry.sampleAViewer;
    }
    return path;
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
      unawaited(_focusHotspotSelection(content));
    }
    if (mounted) setState(() {});
  }

  /// Damaged plant cell (Sampel A): zoom 3D + highlight, popup opens via controller.
  Future<void> _focusHotspotSelection(OrganelleHotspotContent content) async {
    await widget.sceneEngine.setMaterialHighlight(
      content.nodeId,
      enabled: true,
    );
    if (content.id == OrganelleHotspotId.plantCell) {
      await widget.sceneEngine.smoothZoomToTarget(
        ArNodeIds.sampleA,
        factor: 1.35,
        cameraOrbit: '0deg 65deg 1.1m',
      );
      await _syncNodesFromVisualState();
    }
  }

  void _enableHotspots() {
    _hotspots.setEnabled(true);
    // Don't pile a second "Petunjuk" card on top of the Mode AR HUD.
    _hotspots.dismissIntro();
    _introDismissTimer?.cancel();
    _introDismissTimer = null;
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

  /// Scene 1 after plane tap / fallback ready: one merged scene GLB.
  /// Does not advance the mission sequence (GAP-1).
  Future<void> _finalizePlacement() async {
    final scenePath =
        ArAssetRegistry.modelForStep(widget.missionCode, widget.stepCode) ??
            ArAssetRegistry.primaryModelForMission(widget.missionCode);
    await widget.sceneEngine.initLabScene(
      labTableModelPath: scenePath,
      tempatUjiModelPath: null,
      sampleAModelPath: scenePath,
      sampleBModelPath: scenePath,
      sampleOffsetX: _sampleOffsetX,
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
    _introDismissTimer?.cancel();
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
    return ColoredBox(
      color: const Color(0xFF1A1F24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MissionScenePanel.debugUsePlaceholderScene
              ? _buildPlaceholder(theme)
              : (_wantsLiveAr
                    ? _buildArView(visual)
                    : _buildModelViewer()),
          _buildTopHud(theme),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSecondaryOverlay(theme),
                _buildBottomControls(theme),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            // Sit above the bottom controls bar (~72dp) + system nav inset.
            bottom: 72 + MediaQuery.viewPaddingOf(context).bottom,
            child: _buildHotspotSheet(),
          ),
        ],
      ),
    );
  }

  /// Test-only debug / gesture affordances — hidden in production builds.
  Widget _buildSecondaryOverlay(ThemeData theme) {
    if (!MissionScenePanel.debugUsePlaceholderScene) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.useAr) _buildDebugArControls(),
              _buildGestureControls(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHud(ThemeData theme) {
    final statusLine = widget.stepLabel.trim().isNotEmpty &&
            widget.stepLabel != '—'
        ? '${widget.statusLabel} · ${widget.stepLabel}'
        : widget.statusLabel;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
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
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!_wantsLiveAr &&
                          widget.onRequestLiveAr != null &&
                          _capability?.supported == true)
                        TextButton(
                          key: const Key('mission-activate-live-ar'),
                          onPressed: widget.onRequestLiveAr,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Mode AR'),
                        ),
                      if (_wantsLiveAr)
                        IconButton(
                          key: const Key('mission-reset-scene'),
                          tooltip: 'Reset penempatan scene AR',
                          onPressed: _resetScene,
                          visualDensity: VisualDensity.compact,
                          color: Colors.white,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                        ),
                    ],
                  ),
                  Semantics(
                    liveRegion: true,
                    label: 'Status scene: ${widget.statusLabel}',
                    child: Text(
                      statusLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (_wantsLiveAr && _scanPhase != ArScanPhase.placed) ...[
                    const SizedBox(height: 2),
                    Text(
                      _scanHint,
                      key: const Key('mission-scan-hint'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (_liveInitFailed) ...[
                    const SizedBox(height: 4),
                    Text(
                      'AR gagal — mode 3D (fallback).',
                      key: const Key('mission-fallback-banner'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.errorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (widget.sequencePaused && _wantsLiveAr) ...[
                    const SizedBox(height: 4),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Pelacakan AR hilang — sequence dijeda.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.errorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_arError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _arError!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.errorContainer,
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

  void _onRunStepPressed() {
    // Clear stacked observation UI so step visuals stay readable.
    _hotspots.closePopup();
    _hotspots.dismissIntro();
    widget.onRunStep();
  }

  Widget _buildBottomControls(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Semantics(
              button: true,
              enabled: _canRunStep,
              label: 'Jalankan langkah scene berikutnya',
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  key: const Key('mission-run-step'),
                  onPressed: _canRunStep ? _onRunStepPressed : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Jalankan Langkah'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureControls(ThemeData theme) {
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: Colors.white,
      visualDensity: VisualDensity.compact,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 0,
        children: [
          TextButton(
            key: const Key('mission-gesture-pinch-out'),
            style: buttonStyle,
            onPressed: widget.sequencePaused
                ? null
                : () => _adjustScale(1.15),
            child: const Text('Perbesar'),
          ),
          TextButton(
            key: const Key('mission-gesture-pinch-in'),
            style: buttonStyle,
            onPressed: widget.sequencePaused
                ? null
                : () => _adjustScale(1 / 1.15),
            child: const Text('Perkecil'),
          ),
          TextButton(
            key: const Key('mission-gesture-rotate'),
            style: buttonStyle,
            onPressed: widget.sequencePaused ? null : () => _nudgeRotation(),
            child: const Text('Putar'),
          ),
          TextButton(
            key: const Key('mission-gesture-reset-transform'),
            style: buttonStyle,
            onPressed: widget.sequencePaused ? null : _resetTransform,
            child: const Text('Kembali ke posisi awal'),
          ),
          TextButton(
            key: const Key('mission-tap-chloroplast'),
            style: buttonStyle,
            onPressed: widget.sequencePaused
                ? null
                : () => _selectStructure('kloroplas'),
            child: const Text('Ketuk kloroplas'),
          ),
          TextButton(
            key: const Key('mission-tap-vacuole'),
            style: buttonStyle,
            onPressed: widget.sequencePaused
                ? null
                : () => _selectStructure('vakuola'),
            child: const Text('Ketuk vakuola'),
          ),
          TextButton(
            key: const Key('mission-tap-membrane'),
            style: buttonStyle,
            onPressed: widget.sequencePaused
                ? null
                : () => _selectStructure('membran'),
            child: const Text('Ketuk membran'),
          ),
          if (_wantsLiveAr && _scanPhase == ArScanPhase.placed)
            Text(
              'Ketuk bidang lagi untuk reposisi (anchor baru).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
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
      ArScanPhase.planeReady => 'Bidang terdeteksi — ketuk untuk menempatkan.',
      ArScanPhase.placed =>
        'Meja Laboratorium + Sampel A & B ditempatkan. Jalankan langkah untuk memulai misi.',
      _ => '',
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
    final step = widget.stepCode;

    // Same mapping as AR: registry drives scene GLB per mission + step.
    final glbPath = ArAssetRegistry.modelForStep(widget.missionCode, step) ??
        ArAssetRegistry.primaryModelForMission(widget.missionCode);
    final src = ArAssetRegistry.modelViewerSrc(glbPath, forWeb: kIsWeb);

    final orbit = ArAssetRegistry.cameraOrbitForStep(step);

    return Stack(
      fit: StackFit.expand,
      children: [
        ModelViewer(
          key: ValueKey('mv-lab-$glbPath-$step'),
          src: src,
          alt: 'Meja laboratorium forensik sel',
          ar: false,
          autoRotate: false,
          cameraControls: true,
          disableZoom: false,
          cameraOrbit: orbit,
          backgroundColor: const Color(0xFF1A1F24),
          loading: Loading.eager,
          relatedCss: 'body{margin:0;background:#1A1F24}',
        ),
        if (_wantsLiveAr)
          ArSceneOverlayLayer(
            effect: visual.overlay,
            highlightTarget: visual.highlightTarget,
            opacity: visual.opacity,
            dualSamples: false,
          ),
        _buildModelTapLayer(dualSamples: false),
      ],
    );
  }

  Widget _buildModelTapLayer({required bool dualSamples}) {
    return Align(
      alignment: dualSamples ? Alignment.centerLeft : Alignment.center,
      child: FractionallySizedBox(
        widthFactor: dualSamples ? 0.5 : 0.72,
        heightFactor: 0.72,
        child: Semantics(
          button: true,
          label: SampleAOrganelleHotspots.plantCell.semanticsLabel,
          child: GestureDetector(
            key: const Key('model-viewer-plant-cell-tap'),
            behavior: HitTestBehavior.translucent,
            onTap: () => _hotspots.select(OrganelleHotspotId.plantCell),
          ),
        ),
      ),
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
        // Auto-place on first detected plane — no tap needed.
        unawaited(_autoPlaceOnFirstPlane());
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

  Future<void> _autoPlaceOnFirstPlane() async {
    if (_scanPhase == ArScanPhase.placed) return;
    if (_anchors == null || _session == null) return;
    // Place at world origin of the detected plane.
    // ponytail: uses (0,0,0); upgrade to center hit-test when plugin exposes screenHitTest.
    final anchor = ARPlaneAnchor(
      transformation: Matrix4.identity(),
    );
    final added = await _anchors!.addAnchor(anchor);
    if (added != true || !mounted) return;
    await widget.sceneEngine.place(const ArPlacement(x: 0, y: 0, z: 0));
    _lifecycle.confirmRelocalized();
    widget.sceneEngine.updateTracking(ArTrackingState.tracking);
    setState(() {
      _placedAnchor = anchor;
      _scanPhase = ArScanPhase.placed;
      _liveInitFailed = false;
      _arError = null;
    });
    widget.onPlacementChanged?.call(true);
    await _finalizePlacement();
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
    if (_tempatUjiANode != null) {
      objects.removeNode(_tempatUjiANode!);
    }
    if (_tempatUjiBNode != null) {
      objects.removeNode(_tempatUjiBNode!);
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
    // Primary/sample nodes now carry the merged scene GLB (full desk), so they
    // share the lab-table footprint scale — not the old solo-cell 0.20 scale.
    final base = switch (nodeId) {
      ArNodeIds.tempatUjiA || ArNodeIds.tempatUjiB => _tempatUjiBaseScale,
      ArNodeIds.labTable ||
      ArNodeIds.primary ||
      ArNodeIds.sampleA ||
      ArNodeIds.sampleB =>
        _labTableBaseScale,
      _ => _baseScale,
    };
    // Prefer component-wise so non-uniform director scales still apply.
    return Vector3(
      base * _gestureScale * seq.x,
      base * _gestureScale * seq.y,
      base * _gestureScale * seq.z,
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

    await _syncTempatUjiNode(
      objects: objects,
      anchor: anchor,
      visual: visual,
      nodeId: ArNodeIds.tempatUjiA,
      current: _tempatUjiANode,
      assign: (node) => _tempatUjiANode = node,
    );
    await _syncTempatUjiNode(
      objects: objects,
      anchor: anchor,
      visual: visual,
      nodeId: ArNodeIds.tempatUjiB,
      current: _tempatUjiBNode,
      assign: (node) => _tempatUjiBNode = node,
    );
    final trayPathA = visual.nodeModels[ArNodeIds.tempatUjiA];
    final trayPathB = visual.nodeModels[ArNodeIds.tempatUjiB];
    _tempatUjiAssetPath = trayPathA ?? trayPathB;

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
          ArVec3(visual.secondaryOffsetX, 0.76, -0.30);
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

  Future<void> _syncTempatUjiNode({
    required ARObjectManager objects,
    required ARPlaneAnchor anchor,
    required ArSceneVisualState visual,
    required String nodeId,
    required ARNode? current,
    required void Function(ARNode?) assign,
  }) async {
    final path = visual.nodeModels[nodeId];
    final visible = visual.visibleNodes[nodeId] ?? (path != null);
    if (path == null || !visible) {
      if (current != null) {
        objects.removeNode(current);
        assign(null);
      }
      return;
    }
    final existing = current;
    if (existing != null && _tempatUjiAssetPath == path) {
      existing.scale = _liveScaleFor(nodeId);
      existing.eulerAngles = Vector3(0, _gestureRotationY, 0);
      existing.position = _vecFromAr(
        visual.nodePosition[nodeId] ?? ArVec3.zero,
      );
      return;
    }
    if (existing != null) {
      objects.removeNode(existing);
    }
    final node = await _createNodeForAsset(
      path,
      position: _vecFromAr(visual.nodePosition[nodeId] ?? ArVec3.zero),
      nodeId: nodeId,
    );
    final ok = await objects.addNode(node, planeAnchor: anchor);
    assign(ok == true ? node : null);
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
      } else if (mounted) {
        setState(() {
          _arError =
              'Gagal memuat model GLB ke scene AR '
              '(${assetPath.split('/').last}).';
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
    void applyTray(ARNode? node, String nodeId) {
      if (node == null) return;
      node.scale = _liveScaleFor(nodeId);
      node.eulerAngles = Vector3(0, _gestureRotationY, 0);
      node.position = _vecFromAr(
        visual.nodePosition[nodeId] ?? ArVec3.zero,
      );
    }

    applyTray(_tempatUjiANode, ArNodeIds.tempatUjiA);
    applyTray(_tempatUjiBNode, ArNodeIds.tempatUjiB);
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
          ArVec3(visual.secondaryOffsetX, 0.76, -0.30);
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
      _tempatUjiANode = null;
      _tempatUjiBNode = null;
      _placedNode = null;
      _secondaryNode = null;
      _labTableAssetPath = null;
      _tempatUjiAssetPath = null;
      _placedAssetPath = null;
      _secondaryAssetPath = null;
      _scanPhase = ArScanPhase.scanning;
      _arError = null;
      _gestureScale = 1;
      _gestureRotationY = 0;
    });
    widget.onPlacementChanged?.call(false);
  }
}
