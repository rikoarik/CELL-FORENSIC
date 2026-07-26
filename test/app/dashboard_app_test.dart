import 'package:cell_forensic/app/dashboard_home.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/scoring/scoring_engine.dart';
import 'package:cell_forensic/features/dashboard/dashboard_models.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard menampilkan ringkasan sesi responsif', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardHome(
          repository: FakeDashboardSessionRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan Sesi'), findsOneWidget);
    expect(find.text('Belum ada sesi'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-wide-layout')), findsOneWidget);
    expect(find.bySemanticsLabel('Ringkasan sesi praktikum'), findsOneWidget);
  });

  testWidgets('dashboard beradaptasi pada layar sempit', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardHome(
          repository: FakeDashboardSessionRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-compact-layout')), findsOneWidget);
  });

  testWidgets('dashboard menampilkan sesi aktif dan navigasi ke detail kelompok', (
    tester,
  ) async {
    const session = LearningSession(
      id: 's1',
      joinCode: 'CELL01',
      contentVersionId: 'c1',
      status: SessionStatus.active,
      stationDurationSeconds: 300,
      title: 'Praktikum Demo',
    );
    const group = Group(
      id: 'g1',
      sessionId: 's1',
      name: 'Kelompok Mawar',
      members: [
        GroupMember(id: 'm1', displayName: 'Ani', isLeader: true),
      ],
    );

    const question = DashboardQuestionMeta(
      id: 'q1',
      code: 'POS1-Q1',
      text: 'Soal demo',
      type: QuestionType.objective,
      maxScore: 10,
      correctAnswer: 'Ya',
      stationCode: 'POS-1',
    );
    final score = const ScoringEngine().scoreAnswer(
      question: question.toScoringQuestion(),
      answerText: 'Ya',
    );

    final fake = FakeDashboardSessionRepository(
      [
        DashboardSessionSnapshot(
          session: session,
          groups: const [group],
          pendingReviewCount: 0,
        ),
      ],
      {
        group.id: DashboardGroupDetail(
          session: session,
          group: group,
          missionProgress: const [],
          answers: [
            DashboardAnswerReview(
              answerId: 'a1',
              groupId: 'g1',
              question: question,
              answerText: 'Ya',
              storedAutoScore: 10,
              storedTeacherScore: null,
              storedFinalScore: 10,
              feedback: null,
              version: 1,
              score: score,
            ),
          ],
        ),
      },
      [
        const DashboardExportRow(
          sessionJoinCode: 'CELL01',
          sessionTitle: 'Praktikum Demo',
          groupName: 'Kelompok Mawar',
          memberNames: 'Ani',
          questionCode: 'POS1-Q1',
          questionType: 'objective',
          stationCode: 'POS-1',
          answerText: 'Ya',
          autoScore: 10,
          teacherScore: null,
          finalScore: 10,
          requiresReview: false,
          feedback: '',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardHome(repository: fake)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Praktikum Demo'), findsOneWidget);
    expect(find.text('Kelompok Mawar'), findsOneWidget);
    expect(find.textContaining('Ani'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-tile-g1')));
    await tester.pumpAndSettle();

    expect(find.text('Kelompok Mawar'), findsWidgets);
    expect(find.textContaining('Soal demo'), findsOneWidget);
    expect(find.textContaining('Skor otomatis: 10/10'), findsOneWidget);
  });

  testWidgets('tombol ekspor CSV menyalin ke papan klip di lingkungan uji', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    const session = LearningSession(
      id: 's1',
      joinCode: 'CELL01',
      contentVersionId: 'c1',
      status: SessionStatus.active,
      stationDurationSeconds: 300,
      title: 'Praktikum Demo',
    );

    final fake = FakeDashboardSessionRepository(
      [
        DashboardSessionSnapshot(
          session: session,
          groups: const [],
        ),
      ],
      null,
      [
        const DashboardExportRow(
          sessionJoinCode: 'CELL01',
          sessionTitle: 'Praktikum Demo',
          groupName: 'Kelompok Mawar',
          memberNames: 'Ani',
          questionCode: 'POS1-Q1',
          questionType: 'objective',
          stationCode: 'POS-1',
          answerText: 'Ya',
          autoScore: 10,
          teacherScore: null,
          finalScore: 10,
          requiresReview: false,
          feedback: '',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardHome(repository: fake)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-csv-s1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('CSV disalin'), findsOneWidget);
  });
}
