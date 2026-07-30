import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/journey_host.dart';
import 'package:cell_forensic/features/journey/screens/intro/join_group_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/in_memory_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentJourney _journey() =>
    StudentJourney(content: buildLocalContentPack())
      ..completeDeviceCheck(arSupported: true);

InMemorySessionRepository _repo() => InMemorySessionRepository(
  sessions: [localSeedSession(buildLocalContentPack())],
);

Widget _wrap(StudentJourney journey, {InMemorySessionRepository? repo}) =>
    MaterialApp(
      home: JoinGroupScreen(
        journey: journey,
        sessionRepository: repo ?? _repo(),
      ),
    );

void main() {
  testWidgets('shows the session join code field', (tester) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(journey));

    expect(find.byKey(const Key('joinCodeField')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('joinCodeField')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('joining by code then creating group reaches Scene 1 AR', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(journey));

    await tester.enterText(
      find.byKey(const Key('joinCodeField')),
      journey.content.joinCode,
    );
    await tester.tap(find.byKey(const Key('joinSessionButton')));
    await tester.pumpAndSettle();
    expect(journey.stage, JourneyStage.groupSetup);

    await tester.enterText(
      find.byKey(const Key('joinGroupNameField')),
      'Kelompok Mawar',
    );
    await tester.enterText(find.byKey(const Key('joinLeaderNameField')), 'Ani');
    await tester.tap(find.byKey(const Key('createGroupButton')));
    await tester.pumpAndSettle();

    expect(journey.groupName, 'Kelompok Mawar');
    expect(journey.leaderName, 'Ani');
    expect(journey.missionProgress, isEmpty);
    expect(find.byKey(const Key('addMemberField')), findsOneWidget);

    final continueBtn = find.byKey(const Key('continueOnboardingButton'));
    await tester.ensureVisible(continueBtn);
    await tester.pumpAndSettle();
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    expect(journey.stage, JourneyStage.investigating);
    expect(journey.hasRunningMission, isFalse);
    expect(journey.missionProgress, isEmpty);
  });

  testWidgets('can add member and promote a new leader', (tester) async {
    final journey = _journey();
    final repo = _repo();
    await tester.pumpWidget(_wrap(journey, repo: repo));

    await tester.enterText(
      find.byKey(const Key('joinCodeField')),
      journey.content.joinCode,
    );
    await tester.tap(find.byKey(const Key('joinSessionButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('joinGroupNameField')),
      'Tim A',
    );
    await tester.enterText(find.byKey(const Key('joinLeaderNameField')), 'Ani');
    await tester.tap(find.byKey(const Key('createGroupButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('addMemberField')), 'Budi');
    await tester.tap(find.byKey(const Key('addMemberButton')));
    await tester.pumpAndSettle();

    expect(journey.members, hasLength(2));
    final budi = journey.members.firstWhere((m) => m.displayName == 'Budi');
    await tester.tap(find.byKey(Key('promote_${budi.id}')));
    await tester.pumpAndSettle();

    expect(journey.leaderName, 'Budi');
    expect(journey.members.where((m) => m.isLeader), hasLength(1));
  });

  testWidgets('shows lastError when joining with empty code', (tester) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(journey));

    await tester.enterText(find.byKey(const Key('joinCodeField')), '   ');
    await tester.tap(find.byKey(const Key('joinSessionButton')));
    await tester.pump();

    expect(journey.stage, JourneyStage.joinSession);
    expect(journey.lastError, isNotNull);
    expect(find.text(journey.lastError!), findsOneWidget);
  });

  testWidgets('Buat Kelompok Baru clears group and shows create form', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(journey));

    await tester.enterText(
      find.byKey(const Key('joinCodeField')),
      journey.content.joinCode,
    );
    await tester.tap(find.byKey(const Key('joinSessionButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('joinGroupNameField')),
      'Tim Lama',
    );
    await tester.enterText(find.byKey(const Key('joinLeaderNameField')), 'Ani');
    await tester.tap(find.byKey(const Key('createGroupButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('changeGroupButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('changeGroupButton')));
    await tester.pumpAndSettle();

    expect(journey.group, isNull);
    expect(find.byKey(const Key('joinGroupNameField')), findsOneWidget);
    expect(find.byKey(const Key('createGroupButton')), findsOneWidget);
  });
}
