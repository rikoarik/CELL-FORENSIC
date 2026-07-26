import 'package:flutter/foundation.dart';

/// Intent-driven mission lifecycle (PDF Scene 2). Not a linear wizard index.
enum MissionStatus { locked, available, running, completed }

/// Per-mission progress for Misi 1–3.
@immutable
class MissionProgress {
  const MissionProgress({
    required this.status,
    this.startedAt,
    this.completedAt,
  });

  final MissionStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;

  static const logicalIds = <String>['mission1', 'mission2', 'mission3'];

  static String keyFor(int missionNumber) {
    assert(missionNumber >= 1 && missionNumber <= 3);
    return 'mission$missionNumber';
  }

  static int? numberForKey(String key) {
    return switch (key) {
      'mission1' => 1,
      'mission2' => 2,
      'mission3' => 3,
      _ => null,
    };
  }

  bool get isCompleted => status == MissionStatus.completed;
  bool get isRunning => status == MissionStatus.running;
  bool get isAvailable => status == MissionStatus.available;

  MissionProgress copyWith({
    MissionStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) => MissionProgress(
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
  );
}

/// Helpers for the live intent-driven progress map.
class MissionProgressMap {
  MissionProgressMap._();

  /// Empty map — no orphan progress before group / placement.
  static Map<String, MissionProgress> empty() => {};

  /// After AR lab placement: all three missions become available (unless
  /// already running/completed from a restored session).
  static Map<String, MissionProgress> allAvailable(
    Map<String, MissionProgress> current,
  ) {
    final next = Map<String, MissionProgress>.from(current);
    for (final key in MissionProgress.logicalIds) {
      final existing = next[key];
      if (existing == null || existing.status == MissionStatus.locked) {
        next[key] = const MissionProgress(status: MissionStatus.available);
      }
    }
    return next;
  }
}
