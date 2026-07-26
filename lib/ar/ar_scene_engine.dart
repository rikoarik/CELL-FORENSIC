import 'dart:async';

class ArCapabilities {
  const ArCapabilities({
    required this.supportsPlaneDetection,
    required this.supportsAnchors,
    required this.isFallback,
  });

  final bool supportsPlaneDetection;
  final bool supportsAnchors;
  final bool isFallback;
}

class ArPlacement {
  const ArPlacement({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) =>
      other is ArPlacement && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Simple 3-vector for node transform commands (E11).
class ArVec3 {
  const ArVec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const one = ArVec3(1, 1, 1);
  static const zero = ArVec3(0, 0, 0);

  @override
  bool operator ==(Object other) =>
      other is ArVec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

enum ArTrackingState { tracking, lost }

enum ArSceneCommandType { place, action, reset, visual }

enum ArSceneEventType {
  commandAccepted,
  placementCompleted,
  actionCompleted,
  trackingChanged,
  resetCompleted,
  visualChanged,
}

/// Anchored Flutter overlays when native particles/materials are unavailable.
enum ArOverlayEffect {
  none,
  chloroplastHighlight,
  vacuoleDamage,
  membraneDamage,
  waterLeak,
  cellWallHighlight,
  missingStructureCross,
  forceArrows,
  comparisonLabels,
}

/// Stable node ids used by [ArSceneEngine] visual APIs.
abstract final class ArNodeIds {
  static const primary = 'primary';
  static const labTable = 'lab_table';
  static const sampleA = 'sample_a';
  static const sampleB = 'sample_b';
  static const chloroplast = 'chloroplast';
  static const vacuole = 'vacuole';
  static const membrane = 'membrane';
  static const cellWall = 'cell_wall';
}

/// Snapshot of visual directives applied to the live/fallback scene (E11).
class ArSceneVisualState {
  const ArSceneVisualState({
    this.visibleNodes = const {ArNodeIds.primary: true},
    this.nodeScale = const {},
    this.nodeRotationY = const {},
    this.nodePosition = const {},
    this.highlightTarget,
    this.opacity = 1,
    this.labTableModelPath,
    this.activeModelPath,
    this.secondaryModelPath,
    this.secondaryOffsetX = 0.12,
    this.overlay = ArOverlayEffect.none,
    this.userScale = 1,
    this.userRotationY = 0,
  });

  final Map<String, bool> visibleNodes;
  final Map<String, ArVec3> nodeScale;
  final Map<String, double> nodeRotationY;
  final Map<String, ArVec3> nodePosition;
  final String? highlightTarget;
  final double opacity;

  /// Persistent Meja Laboratorium base model kept anchored across missions
  /// (Scene 1). `null` before the lab scene is initialized.
  final String? labTableModelPath;
  final String? activeModelPath;
  final String? secondaryModelPath;
  final double secondaryOffsetX;
  final ArOverlayEffect overlay;
  final double userScale;
  final double userRotationY;

  ArSceneVisualState copyWith({
    Map<String, bool>? visibleNodes,
    Map<String, ArVec3>? nodeScale,
    Map<String, double>? nodeRotationY,
    Map<String, ArVec3>? nodePosition,
    String? highlightTarget,
    bool clearHighlight = false,
    double? opacity,
    String? labTableModelPath,
    bool clearLabTable = false,
    String? activeModelPath,
    bool clearActiveModel = false,
    String? secondaryModelPath,
    bool clearSecondaryModel = false,
    double? secondaryOffsetX,
    ArOverlayEffect? overlay,
    double? userScale,
    double? userRotationY,
  }) {
    return ArSceneVisualState(
      visibleNodes: visibleNodes ?? this.visibleNodes,
      nodeScale: nodeScale ?? this.nodeScale,
      nodeRotationY: nodeRotationY ?? this.nodeRotationY,
      nodePosition: nodePosition ?? this.nodePosition,
      highlightTarget:
          clearHighlight ? null : (highlightTarget ?? this.highlightTarget),
      opacity: opacity ?? this.opacity,
      labTableModelPath: clearLabTable
          ? null
          : (labTableModelPath ?? this.labTableModelPath),
      activeModelPath:
          clearActiveModel ? null : (activeModelPath ?? this.activeModelPath),
      secondaryModelPath: clearSecondaryModel
          ? null
          : (secondaryModelPath ?? this.secondaryModelPath),
      secondaryOffsetX: secondaryOffsetX ?? this.secondaryOffsetX,
      overlay: overlay ?? this.overlay,
      userScale: userScale ?? this.userScale,
      userRotationY: userRotationY ?? this.userRotationY,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ArSceneVisualState &&
      other.opacity == opacity &&
      other.highlightTarget == highlightTarget &&
      other.labTableModelPath == labTableModelPath &&
      other.activeModelPath == activeModelPath &&
      other.secondaryModelPath == secondaryModelPath &&
      other.secondaryOffsetX == secondaryOffsetX &&
      other.overlay == overlay &&
      other.userScale == userScale &&
      other.userRotationY == userRotationY &&
      _mapEq(other.visibleNodes, visibleNodes) &&
      _mapEq(other.nodeScale, nodeScale) &&
      _mapEq(other.nodeRotationY, nodeRotationY) &&
      _mapEq(other.nodePosition, nodePosition);

  @override
  int get hashCode => Object.hash(
    opacity,
    highlightTarget,
    labTableModelPath,
    activeModelPath,
    secondaryModelPath,
    overlay,
    userScale,
    userRotationY,
  );
}

bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

class ArSceneEvent {
  const ArSceneEvent({
    required this.sequence,
    required this.type,
    required this.command,
    this.actionId,
    this.trackingState,
  });

  final int sequence;
  final ArSceneEventType type;
  final ArSceneCommandType command;
  final String? actionId;
  final ArTrackingState? trackingState;

  @override
  bool operator ==(Object other) =>
      other is ArSceneEvent &&
      other.sequence == sequence &&
      other.type == type &&
      other.command == command &&
      other.actionId == actionId &&
      other.trackingState == trackingState;

  @override
  int get hashCode =>
      Object.hash(sequence, type, command, actionId, trackingState);
}

/// Dart-facing AR scene command surface (FR-121).
///
/// Real AR and fallback 3D both speak this interface so mission flow stays
/// identical while [MissionScenePanel] owns platform views.
///
/// E11 adds optional node/material/overlay APIs. Implementations may approximate
/// missing native material APIs via GLB swap + Flutter overlays.
abstract interface class ArSceneEngine {
  ArCapabilities get capabilities;
  Stream<ArSceneEvent> get events;
  ArPlacement? get placement;
  bool get isPaused;
  ArTrackingState get trackingState;
  ArSceneVisualState get visualState;

  Future<void> place(ArPlacement placement);

  /// Initializes Scene 1: Meja Laboratorium base with Sample A (plant) and
  /// Sample B (animal) both visible on the table. Does NOT start any mission
  /// sequence — the lab table stays anchored across later mission actions.
  Future<void> initLabScene({
    required String labTableModelPath,
    required String sampleAModelPath,
    required String sampleBModelPath,
    double sampleOffsetX,
  });

  Future<void> runAction(String actionId);
  Future<void> reset();
  void updateTracking(ArTrackingState state);
  Future<void> dispose();

  // --- E11 visual command surface (non-breaking additions) ---
  Future<void> showNode(String nodeId);
  Future<void> hideNode(String nodeId);
  Future<void> setNodeScale(String nodeId, ArVec3 scale);
  Future<void> setNodeRotation(String nodeId, ArVec3 eulerRadians);
  Future<void> setNodePosition(String nodeId, ArVec3 position);
  Future<void> setMaterialHighlight(String nodeId, {required bool enabled});
  Future<void> setOpacity(double opacity);
  Future<void> replaceModelAtActiveAnchor(String assetPath);
  Future<void> resetTransform();
  Future<void> showAnchoredOverlayEffect(ArOverlayEffect effect);
  Future<void> setSecondaryModel(String? assetPath, {double offsetX = 0.12});
  Future<void> setUserTransform({double? scale, double? rotationY});
}

/// Shared controllable engine used by both Fake (fallback) and Live (plugin) paths.
class ControllableArSceneEngine implements ArSceneEngine {
  ControllableArSceneEngine({required this.capabilities});

  final _events = StreamController<ArSceneEvent>.broadcast(sync: true);
  final _pending = <_PendingAction>[];
  final _completedActions = <String>{};
  int _nextSequence = 0;
  ArTrackingState _tracking = ArTrackingState.tracking;
  ArSceneVisualState _visual = const ArSceneVisualState();

  @override
  final ArCapabilities capabilities;

  @override
  Stream<ArSceneEvent> get events => _events.stream;

  @override
  ArPlacement? placement;

  @override
  ArTrackingState get trackingState => _tracking;

  @override
  bool get isPaused => _tracking == ArTrackingState.lost;

  @override
  ArSceneVisualState get visualState => _visual;

  @override
  Future<void> place(ArPlacement value) async {
    final sequence = ++_nextSequence;
    _emit(sequence, ArSceneEventType.commandAccepted, ArSceneCommandType.place);
    placement = value;
    _emit(
      sequence,
      ArSceneEventType.placementCompleted,
      ArSceneCommandType.place,
    );
  }

  @override
  Future<void> initLabScene({
    required String labTableModelPath,
    required String sampleAModelPath,
    required String sampleBModelPath,
    double sampleOffsetX = 0.11,
  }) async {
    // Scene 1 base: lab table + both samples on top. This is a visual setup
    // only — no [runAction]/sequence advancement happens here.
    final sampleY = 0.03;
    _setVisual(
      _visual.copyWith(
        labTableModelPath: labTableModelPath,
        activeModelPath: sampleAModelPath,
        secondaryModelPath: sampleBModelPath,
        secondaryOffsetX: sampleOffsetX,
        overlay: ArOverlayEffect.comparisonLabels,
        nodeScale: const {},
        nodeRotationY: const {},
        nodePosition: {
          ArNodeIds.labTable: ArVec3.zero,
          ArNodeIds.primary: ArVec3(-sampleOffsetX, sampleY, 0),
          ArNodeIds.sampleA: ArVec3(-sampleOffsetX, sampleY, 0),
          ArNodeIds.sampleB: ArVec3(sampleOffsetX, sampleY, 0),
        },
        visibleNodes: const {
          ArNodeIds.labTable: true,
          ArNodeIds.primary: true,
          ArNodeIds.sampleA: true,
          ArNodeIds.sampleB: true,
        },
        // Fresh lab — clear any leftover mission highlight / opacity.
        clearHighlight: true,
        opacity: 1,
        userScale: 1,
        userRotationY: 0,
      ),
    );
  }

  @override
  Future<void> runAction(String actionId) {
    if (_completedActions.contains(actionId)) return Future.value();
    final sequence = ++_nextSequence;
    _emit(
      sequence,
      ArSceneEventType.commandAccepted,
      ArSceneCommandType.action,
      actionId: actionId,
    );
    if (!isPaused) {
      _complete(sequence, actionId);
      return Future.value();
    }
    final completer = Completer<void>();
    _pending.add(_PendingAction(sequence, actionId, completer));
    return completer.future;
  }

  @override
  Future<void> reset() async {
    final sequence = ++_nextSequence;
    _emit(sequence, ArSceneEventType.commandAccepted, ArSceneCommandType.reset);
    placement = null;
    _completedActions.clear();
    for (final pending in _pending) {
      if (!pending.completer.isCompleted) {
        pending.completer.complete();
      }
    }
    _pending.clear();
    _visual = const ArSceneVisualState();
    _emit(sequence, ArSceneEventType.resetCompleted, ArSceneCommandType.reset);
    _emitVisualChanged(sequence);
  }

  @override
  void updateTracking(ArTrackingState state) {
    if (_tracking == state) return;
    _tracking = state;
    final sequence = ++_nextSequence;
    _events.add(
      ArSceneEvent(
        sequence: sequence,
        type: ArSceneEventType.trackingChanged,
        command: ArSceneCommandType.action,
        trackingState: state,
      ),
    );
    if (isPaused) return;
    final pending = List<_PendingAction>.of(_pending);
    _pending.clear();
    for (final action in pending) {
      _complete(action.sequence, action.actionId);
      if (!action.completer.isCompleted) {
        action.completer.complete();
      }
    }
  }

  @override
  Future<void> showNode(String nodeId) async {
    final next = Map<String, bool>.of(_visual.visibleNodes)..[nodeId] = true;
    _setVisual(_visual.copyWith(visibleNodes: next));
  }

  @override
  Future<void> hideNode(String nodeId) async {
    final next = Map<String, bool>.of(_visual.visibleNodes)..[nodeId] = false;
    _setVisual(_visual.copyWith(visibleNodes: next));
  }

  @override
  Future<void> setNodeScale(String nodeId, ArVec3 scale) async {
    final next = Map<String, ArVec3>.of(_visual.nodeScale)..[nodeId] = scale;
    _setVisual(_visual.copyWith(nodeScale: next));
  }

  @override
  Future<void> setNodeRotation(String nodeId, ArVec3 eulerRadians) async {
    final next = Map<String, double>.of(_visual.nodeRotationY)
      ..[nodeId] = eulerRadians.y;
    _setVisual(_visual.copyWith(nodeRotationY: next));
  }

  @override
  Future<void> setNodePosition(String nodeId, ArVec3 position) async {
    final next = Map<String, ArVec3>.of(_visual.nodePosition)
      ..[nodeId] = position;
    _setVisual(_visual.copyWith(nodePosition: next));
  }

  @override
  Future<void> setMaterialHighlight(
    String nodeId, {
    required bool enabled,
  }) async {
    _setVisual(
      _visual.copyWith(
        highlightTarget: enabled ? nodeId : null,
        clearHighlight: !enabled,
      ),
    );
  }

  @override
  Future<void> setOpacity(double opacity) async {
    _setVisual(_visual.copyWith(opacity: opacity.clamp(0.0, 1.0)));
  }

  @override
  Future<void> replaceModelAtActiveAnchor(String assetPath) async {
    _setVisual(_visual.copyWith(activeModelPath: assetPath));
  }

  @override
  Future<void> resetTransform() async {
    _setVisual(
      _visual.copyWith(
        userScale: 1,
        userRotationY: 0,
        nodeScale: const {},
        nodeRotationY: const {},
        nodePosition: const {},
      ),
    );
  }

  @override
  Future<void> showAnchoredOverlayEffect(ArOverlayEffect effect) async {
    _setVisual(_visual.copyWith(overlay: effect));
  }

  @override
  Future<void> setSecondaryModel(
    String? assetPath, {
    double offsetX = 0.12,
  }) async {
    _setVisual(
      _visual.copyWith(
        secondaryModelPath: assetPath,
        clearSecondaryModel: assetPath == null,
        secondaryOffsetX: offsetX,
      ),
    );
  }

  @override
  Future<void> setUserTransform({double? scale, double? rotationY}) async {
    _setVisual(
      _visual.copyWith(
        userScale: scale ?? _visual.userScale,
        userRotationY: rotationY ?? _visual.userRotationY,
      ),
    );
  }

  void _setVisual(ArSceneVisualState next) {
    if (next == _visual) return;
    _visual = next;
    _emitVisualChanged(++_nextSequence);
  }

  void _emitVisualChanged(int sequence) {
    _events.add(
      ArSceneEvent(
        sequence: sequence,
        type: ArSceneEventType.visualChanged,
        command: ArSceneCommandType.visual,
      ),
    );
  }

  void _complete(int sequence, String actionId) {
    if (!_completedActions.add(actionId)) return;
    _emit(
      sequence,
      ArSceneEventType.actionCompleted,
      ArSceneCommandType.action,
      actionId: actionId,
    );
  }

  void _emit(
    int sequence,
    ArSceneEventType type,
    ArSceneCommandType command, {
    String? actionId,
  }) {
    _events.add(
      ArSceneEvent(
        sequence: sequence,
        type: type,
        command: command,
        actionId: actionId,
      ),
    );
  }

  @override
  Future<void> dispose() => _events.close();
}

/// Fallback / test engine — no plane detection required.
class FakeArSceneEngine extends ControllableArSceneEngine {
  FakeArSceneEngine()
    : super(
        capabilities: const ArCapabilities(
          supportsPlaneDetection: false,
          supportsAnchors: true,
          isFallback: true,
        ),
      );
}

/// Live AR plugin engine — plane scan + anchor placement expected.
class LiveArSceneEngine extends ControllableArSceneEngine {
  LiveArSceneEngine()
    : super(
        capabilities: const ArCapabilities(
          supportsPlaneDetection: true,
          supportsAnchors: true,
          isFallback: false,
        ),
      );
}

class _PendingAction {
  const _PendingAction(this.sequence, this.actionId, this.completer);

  final int sequence;
  final String actionId;
  final Completer<void> completer;
}
