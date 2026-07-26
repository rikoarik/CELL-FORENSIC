import 'package:cell_forensic/core/app_services.dart';
import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/intro/device_check_screen.dart';
import 'package:cell_forensic/features/journey/screens/intro/join_group_screen.dart';
import 'package:cell_forensic/features/journey/screens/intro/onboarding_screen.dart';
import 'package:cell_forensic/features/journey/screens/investigation/conclusion_screen.dart';
import 'package:cell_forensic/features/journey/screens/investigation/mission_screen.dart';
import 'package:cell_forensic/features/journey/screens/stations/results_screen.dart';
import 'package:cell_forensic/features/journey/screens/stations/station_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/journey/widgets/journey_progress_bar.dart';
import 'package:cell_forensic/features/session/in_memory_session_repository.dart';
import 'package:cell_forensic/features/session/persisted_session_repository.dart';
import 'package:cell_forensic/features/session/session_repository.dart';
import 'package:cell_forensic/features/session/session_snapshot_store.dart';
import 'package:flutter/material.dart';

/// Hosts the full offline student journey, swapping screens as the shared
/// [StudentJourney] state machine advances.
///
/// Session/group data is backed by [SessionRepository] (persisted when
/// [AppServices] is available) and an optional [SessionSnapshotStore] so a
/// relaunch can restore the joined session (E2-04).
class JourneyHost extends StatefulWidget {
  const JourneyHost({
    super.key,
    this.journey,
    this.sessionRepository,
    this.snapshotStore,
    this.restoreSnapshot = true,
  });

  /// Optional injected journey (tests). Defaults to the seeded local content.
  final StudentJourney? journey;

  /// Optional session repository. Defaults to a persisted store when
  /// [AppServices] is initialized, otherwise an in-memory CELL01 seed.
  final SessionRepository? sessionRepository;

  /// Optional snapshot store for offline restore. Defaults from [AppServices].
  final SessionSnapshotStore? snapshotStore;

  /// Whether to attempt restoring a prior session/group snapshot on start.
  final bool restoreSnapshot;

  @override
  State<JourneyHost> createState() => _JourneyHostState();
}

class _JourneyHostState extends State<JourneyHost> {
  late final ContentPack _content =
      widget.journey?.content ?? buildLocalContentPack();
  late final StudentJourney _journey =
      widget.journey ?? StudentJourney(content: _content);
  late final bool _ownsJourney = widget.journey == null;
  late final SessionRepository _sessionRepository;
  late final SessionSnapshotStore? _snapshotStore;

  @override
  void initState() {
    super.initState();
    _sessionRepository =
        widget.sessionRepository ?? _defaultSessionRepository(_content);
    _snapshotStore =
        widget.snapshotStore ??
        (AppServices.isInitialized
            ? SessionSnapshotStore(AppServices.instance.database)
            : null);

    // Attach before restore so auto-mutations during restore (e.g. expired
    // POS timer → submitActiveStation) are written back to the snapshot store.
    _journey.addListener(_persistSnapshot);

    if (widget.restoreSnapshot) {
      final snap = _snapshotStore?.loadActive();
      if (snap != null) {
        _journey.restoreFromSnapshot(snap);
      }
    }
  }

  void _persistSnapshot() {
    final store = _snapshotStore;
    if (store == null) return;
    final snap = _journey.toSessionSnapshot();
    if (snap != null) store.save(snap);
  }

  @override
  void dispose() {
    _journey.removeListener(_persistSnapshot);
    if (_ownsJourney) _journey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _journey,
      builder: (context, _) {
        final screen = switch (_journey.stage) {
          JourneyStage.deviceCheck => DeviceCheckScreen(journey: _journey),
          JourneyStage.joinSession || JourneyStage.groupSetup => JoinGroupScreen(
            journey: _journey,
            sessionRepository: _sessionRepository,
            snapshotStore: _snapshotStore,
          ),
          JourneyStage.onboarding => OnboardingScreen(journey: _journey),
          JourneyStage.investigating => MissionScreen(journey: _journey),
          JourneyStage.conclusion => ConclusionScreen(journey: _journey),
          JourneyStage.stations => StationScreen(journey: _journey),
          JourneyStage.results => ResultsScreen(journey: _journey),
        };
        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                bottom: false,
                child: JourneyProgressBar(journey: _journey),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_journey.stage),
                    child: screen,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

SessionRepository _defaultSessionRepository(ContentPack content) {
  final seed = localSeedSession(content);
  if (AppServices.isInitialized) {
    return PersistedSessionRepository(
      database: AppServices.instance.database,
      seedSessions: [seed],
    );
  }
  return InMemorySessionRepository(sessions: [seed]);
}

/// Builds the offline-seeded learning session for the local content pack.
LearningSession localSeedSession(ContentPack content) {
  return LearningSession(
    id: 'local-${content.joinCode.toLowerCase()}',
    joinCode: content.joinCode,
    contentVersionId: 'local-content',
    status: SessionStatus.active,
    stationDurationSeconds: content.stationDurationSeconds,
    title: content.sessionTitle,
  );
}

/// Test helper: build a [PersistedSessionRepository] over an ephemeral backend.
PersistedSessionRepository buildTestSessionRepository({
  ContentPack? content,
  LocalDatabase? database,
}) {
  final pack = content ?? buildLocalContentPack();
  return PersistedSessionRepository(
    database: database ?? LocalDatabase(InMemoryStorageBackend()),
    seedSessions: [localSeedSession(pack)],
  );
}
