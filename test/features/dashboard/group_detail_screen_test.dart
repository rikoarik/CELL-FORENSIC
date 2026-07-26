import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/scoring/scoring_engine.dart';
import 'package:cell_forensic/features/dashboard/dashboard_models.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:cell_forensic/features/dashboard/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      GroupMember(id: 'm2', displayName: 'Budi', isLeader: false),
    ],
  );

  const objectiveQ = DashboardQuestionMeta(
    id: 'q1',
    code: 'POS1-Q1',
    text: 'Sampel manakah yang memiliki dinding sel?',
    type: QuestionType.objective,
    maxScore: 10,
    correctAnswer: 'Sampel A',
    stationCode: 'POS-1',
    stationTitle: 'POS 1',
  );

  const essayQ = DashboardQuestionMeta(
    id: 'q2',
    code: 'POS1-Q2',
    text: 'Jelaskan fungsi dinding sel.',
    type: QuestionType.essay,
    maxScore: 5,
    rubric: 'Menyebut pelindung/penyokong.',
    stationCode: 'POS-1',
    stationTitle: 'POS 1',
  );

  DashboardGroupDetail buildDetail() {
    const engine = ScoringEngine();
    final objectiveScore = engine.scoreAnswer(
      question: objectiveQ.toScoringQuestion(),
      answerText: 'Sampel A',
    );
    final essayScore = engine.scoreAnswer(
      question: essayQ.toScoringQuestion(),
      answerText: 'Melindungi dan menyokong bentuk sel.',
    );
    return DashboardGroupDetail(
      session: session,
      group: group,
      missionProgress: const [
        DashboardMissionProgress(
          missionCode: 'MISI-1',
          missionTitle: 'Observasi Sampel A',
          status: 'completed',
          arMode: 'arcore',
        ),
      ],
      conclusion: const DashboardConclusion(
        status: 'submitted',
        sampleAIdentity: 'Sel tumbuhan',
        sampleAReasoning: 'Ada dinding sel',
        sampleBIdentity: 'Sel hewan rusak',
        sampleBReasoning: 'Membran rusak',
        groupHypothesis: 'Kerusakan membran menyebabkan kebocoran.',
      ),
      answers: [
        DashboardAnswerReview(
          answerId: 'a1',
          groupId: 'g1',
          question: objectiveQ,
          answerText: 'Sampel A',
          storedAutoScore: 10,
          storedTeacherScore: null,
          storedFinalScore: 10,
          feedback: null,
          version: 1,
          score: objectiveScore,
        ),
        DashboardAnswerReview(
          answerId: 'a2',
          groupId: 'g1',
          question: essayQ,
          answerText: 'Melindungi dan menyokong bentuk sel.',
          storedAutoScore: null,
          storedTeacherScore: null,
          storedFinalScore: null,
          feedback: null,
          version: 1,
          score: essayScore,
        ),
      ],
    );
  }

  testWidgets('menampilkan detail kelompok dan skor objektif', (tester) async {
    final fake = FakeDashboardSessionRepository(
      [
        DashboardSessionSnapshot(session: session, groups: [group]),
      ],
      {group.id: buildDetail()},
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailScreen(
          repository: fake,
          session: session,
          group: group,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kelompok Mawar'), findsOneWidget);
    expect(find.textContaining('Ani'), findsWidgets);
    expect(find.textContaining('MISI-1'), findsOneWidget);
    expect(find.textContaining('Sampel A'), findsWidgets);
    expect(find.textContaining('Skor otomatis: 10/10'), findsOneWidget);
    expect(find.textContaining('menunggu review'), findsOneWidget);
    expect(find.text('Nilai esai'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-detail-tab-kesimpulan')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sel tumbuhan'), findsOneWidget);
  });

  testWidgets('menyimpan penilaian esai dari sheet review', (tester) async {
    final fake = FakeDashboardSessionRepository(
      [
        DashboardSessionSnapshot(session: session, groups: [group]),
      ],
      {group.id: buildDetail()},
    );

    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailScreen(
          repository: fake,
          session: session,
          group: group,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reviewButton = find.byKey(const Key('review-button-a2'));
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('teacher-score-field')), '4');
    await tester.enterText(
      find.byKey(const Key('teacher-feedback-field')),
      'Bagus',
    );
    await tester.tap(find.byKey(const Key('save-teacher-review')));
    await tester.pumpAndSettle();

    expect(fake.reviewCalls, hasLength(1));
    expect(fake.reviewCalls.single.answerId, 'a2');
    expect(fake.reviewCalls.single.teacherScore, 4);
    expect(fake.reviewCalls.single.feedback, 'Bagus');
    expect(find.text('Penilaian disimpan'), findsOneWidget);
  });

  testWidgets('mode baca saja menonaktifkan tombol penilaian', (tester) async {
    final fake = FakeDashboardSessionRepository(
      [
        DashboardSessionSnapshot(session: session, groups: [group]),
      ],
      {group.id: buildDetail()},
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailScreen(
          repository: fake,
          session: session,
          group: group,
          canManage: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-detail-readonly')), findsOneWidget);
    final review = tester.widget<FilledButton>(
      find.byKey(const Key('review-button-a2')),
    );
    expect(review.onPressed, isNull);
  });
}
