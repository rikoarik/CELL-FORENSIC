import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/scoring/scoring_engine.dart';
import 'package:cell_forensic/features/dashboard/dashboard_models.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drill-down kelompok: anggota, progres misi, kesimpulan, review jawaban (E6-02/03).
class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.group,
    this.canManage = true,
  });

  final DashboardSessionRepository repository;
  final LearningSession session;
  final Group group;

  /// False for unowned / other-teacher sessions (E9 RLS).
  final bool canManage;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<DashboardGroupDetail> _future;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<DashboardGroupDetail> _load() {
    return widget.repository.loadGroupDetail(
      sessionId: widget.session.id,
      groupId: widget.group.id,
    );
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _openReview(DashboardAnswerReview answer) async {
    if (!widget.canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Penilaian hanya untuk sesi yang Anda miliki (atau admin).',
          ),
        ),
      );
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReviewSheet(
        answer: answer,
        onSave: ({
          required num teacherScore,
          String? feedback,
          required int baseVersion,
        }) async {
          await widget.repository.saveTeacherReview(
            answerId: answer.answerId,
            teacherScore: teacherScore,
            feedback: feedback,
            baseVersion: baseVersion,
          );
        },
      ),
    );
    if (saved == true && mounted) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penilaian disimpan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionTitle = widget.session.title.isEmpty
        ? 'Sesi ${widget.session.joinCode}'
        : widget.session.title;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            key: const Key('group-detail-refresh'),
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<DashboardGroupDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceLg),
                child: Text('Gagal memuat: ${snapshot.error}'),
              ),
            );
          }
          final detail = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= DesignTokens.dashboardBreakpoint;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 340,
                        child: ColoredBox(
                          color: Colors.white,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(DesignTokens.spaceLg),
                            child: _SummaryRail(
                              sessionTitle: sessionTitle,
                              joinCode: widget.session.joinCode,
                              detail: detail,
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildTabsPane(detail)),
                    ],
                  );
                }
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(DesignTokens.spaceLg),
                      sliver: SliverToBoxAdapter(
                        child: _SummaryRail(
                          sessionTitle: sessionTitle,
                          joinCode: widget.session.joinCode,
                          detail: detail,
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: _buildTabsPane(detail),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabsPane(DashboardGroupDetail detail) {
    return ColoredBox(
      color: DesignTokens.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: DesignTokens.navy,
              unselectedLabelColor: DesignTokens.inkMuted,
              indicatorColor: DesignTokens.blue,
              tabs: [
                Tab(
                  key: const Key('group-detail-tab-penilaian'),
                  text: detail.pendingReviewCount > 0
                      ? 'Penilaian (${detail.pendingReviewCount})'
                      : 'Penilaian',
                ),
                const Tab(
                  key: Key('group-detail-tab-kesimpulan'),
                  text: 'Kesimpulan',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PenilaianTab(
                  detail: detail,
                  canManage: widget.canManage,
                  onReview: _openReview,
                ),
                _KesimpulanTab(detail: detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRail extends StatelessWidget {
  const _SummaryRail({
    required this.sessionTitle,
    required this.joinCode,
    required this.detail,
  });

  final String sessionTitle;
  final String joinCode;
  final DashboardGroupDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          sessionTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DesignTokens.navy,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DesignTokens.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              joinCode,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceLg),
        _SectionCard(
          title: 'Anggota (${detail.group.members.length})',
          child: detail.group.members.isEmpty
              ? const Text('Belum ada anggota.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in detail.group.members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  DesignTokens.blue.withValues(alpha: 0.12),
                              foregroundColor: DesignTokens.blue,
                              child: Text(
                                m.displayName.isEmpty
                                    ? '?'
                                    : m.displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${m.displayName}${m.isLeader ? ' (ketua)' : ''}',
                              ),
                            ),
                            if (m.isLeader)
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Color(0xFFF0B429),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        _SectionCard(
          title: 'Progres misi',
          child: detail.missionProgress.isEmpty
              ? const Text('Belum ada progres misi.')
              : Column(
                  children: [
                    for (final p in detail.missionProgress)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: _MissionStatusDot(status: p.status),
                        title: Text('${p.missionCode} — ${p.missionTitle}'),
                        subtitle: Text(
                          '${_statusLabel(p.status)} · Mode ${p.arMode}',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'selesai';
      case 'in_progress':
        return 'berjalan';
      case 'not_started':
        return 'belum mulai';
      default:
        return status;
    }
  }
}

class _PenilaianTab extends StatelessWidget {
  const _PenilaianTab({
    required this.detail,
    required this.canManage,
    required this.onReview,
  });

  final DashboardGroupDetail detail;
  final bool canManage;
  final Future<void> Function(DashboardAnswerReview answer) onReview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      children: [
        if (detail.pendingReviewCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8C56A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.rate_review_outlined, color: Color(0xFF8A6A00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${detail.pendingReviewCount} jawaban menunggu review guru.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C4A00),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
            child: Text(
              'Semua jawaban yang membutuhkan review sudah dinilai '
              '(atau belum ada jawaban esai).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (!canManage) ...[
          Text(
            'Mode baca saja — sesi ini tidak dapat Anda nilai.',
            key: const Key('group-detail-readonly'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
        ],
        ..._answerCards(detail),
      ],
    );
  }

  List<Widget> _answerCards(DashboardGroupDetail detail) {
    if (detail.answers.isEmpty) {
      return const [
        _SectionCard(
          title: 'Belum ada jawaban POS',
          child: Text(
            'Jawaban stasiun evaluasi akan muncul di sini setelah '
            'kelompok mengirim POS.',
          ),
        ),
      ];
    }
    return [
      for (final answer in detail.answers)
        Padding(
          key: Key('answer-pad-${answer.answerId}'),
          padding: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
          child: _AnswerCard(
            answer: answer,
            canManage: canManage,
            onReview: () => onReview(answer),
          ),
        ),
    ];
  }
}

class _KesimpulanTab extends StatelessWidget {
  const _KesimpulanTab({required this.detail});

  final DashboardGroupDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      children: [
        _SectionCard(
          title: 'Kesimpulan investigasi',
          child: detail.conclusion == null
              ? const Text('Belum ada draft kesimpulan.')
              : _ConclusionBody(conclusion: detail.conclusion!),
        ),
      ],
    );
  }
}

class _ConclusionBody extends StatelessWidget {
  const _ConclusionBody({required this.conclusion});

  final DashboardConclusion conclusion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: conclusion.isSubmitted
                ? const Color(0xFFE3F8E8)
                : const Color(0xFFEFF3F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            conclusion.isSubmitted ? 'Terkirim' : 'Draf',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: conclusion.isSubmitted
                  ? const Color(0xFF0E7A3D)
                  : DesignTokens.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ConclusionField(
          label: 'Sampel A',
          value: conclusion.sampleAIdentity,
          detail: conclusion.sampleAReasoning,
        ),
        const SizedBox(height: 10),
        _ConclusionField(
          label: 'Sampel B',
          value: conclusion.sampleBIdentity,
          detail: conclusion.sampleBReasoning,
        ),
        const SizedBox(height: 10),
        _ConclusionField(
          label: 'Hipotesis kelompok',
          value: conclusion.groupHypothesis,
        ),
      ],
    );
  }
}

class _ConclusionField extends StatelessWidget {
  const _ConclusionField({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: DesignTokens.inkMuted,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          empty ? '—' : value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (detail != null && detail!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(detail!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _MissionStatusDot extends StatelessWidget {
  const _MissionStatusDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => const Color(0xFF0E7A3D),
      'in_progress' => DesignTokens.blue,
      'not_started' => DesignTokens.border,
      _ => DesignTokens.inkMuted,
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: DesignTokens.spaceSm),
            child,
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.onReview,
    this.canManage = true,
  });

  final DashboardAnswerReview answer;
  final VoidCallback onReview;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final q = answer.question;
    final score = answer.score;
    final isEssay = q.type == QuestionType.essay;
    final typeLabel = isEssay ? 'Esai' : 'Objektif';

    return Card(
      key: Key('answer-card-${answer.answerId}'),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (q.stationCode.isNotEmpty) q.stationCode,
                q.code,
                typeLabel,
              ].where((s) => s.isNotEmpty).join(' · '),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(q.text, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              answer.answerText.isEmpty ? '(kosong)' : answer.answerText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ScoreChip(
                  label: 'Skor otomatis',
                  value: '${score.suggestedScore}/${score.maxScore}',
                ),
                _ScoreChip(
                  label: 'Skor guru',
                  value: score.teacherScore?.toString() ?? '—',
                ),
                _ScoreChip(
                  label: 'Skor akhir',
                  value: score.finalScore?.toString() ?? 'menunggu',
                ),
                if (answer.needsReview)
                  Chip(
                    avatar: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Perlu review'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.amber.shade100,
                  ),
              ],
            ),
            if (q.rubric != null && q.rubric!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Rubrik: ${q.rubric}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (answer.feedback != null && answer.feedback!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Umpan balik: ${answer.feedback}'),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: Key('review-button-${answer.answerId}'),
                onPressed: canManage ? onReview : null,
                child: Text(isEssay ? 'Nilai esai' : 'Tinjau / sesuaikan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.answer, required this.onSave});

  final DashboardAnswerReview answer;
  final Future<void> Function({
    required num teacherScore,
    String? feedback,
    required int baseVersion,
  }) onSave;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _scoreController;
  late final TextEditingController _feedbackController;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.answer.score.teacherScore ??
        (widget.answer.question.type == QuestionType.objective
            ? widget.answer.score.suggestedScore
            : null);
    _scoreController = TextEditingController(
      text: initial?.toString() ?? '',
    );
    _feedbackController = TextEditingController(
      text: widget.answer.feedback ?? '',
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = num.tryParse(_scoreController.text.trim());
    if (parsed == null) {
      setState(() => _error = 'Masukkan skor numerik yang valid.');
      return;
    }
    final max = widget.answer.question.maxScore;
    if (parsed < 0 || parsed > max) {
      setState(() => _error = 'Skor harus antara 0 dan $max.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        teacherScore: parsed,
        feedback: _feedbackController.text.trim().isEmpty
            ? null
            : _feedbackController.text.trim(),
        baseVersion: widget.answer.version,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.answer.question;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review jawaban',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(q.text),
            const SizedBox(height: 12),
            Text(
              'Jawaban siswa:\n${widget.answer.answerText.isEmpty ? '(kosong)' : widget.answer.answerText}',
            ),
            const SizedBox(height: 8),
            Text(
              'Skor otomatis (ScoringEngine): '
              '${widget.answer.score.suggestedScore}/${q.maxScore}'
              '${widget.answer.score.requiresTeacherReview ? ' · butuh konfirmasi guru' : ''}',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('teacher-score-field'),
              controller: _scoreController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Skor guru (maks $max)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('teacher-feedback-field'),
              controller: _feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Umpan balik (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-teacher-review'),
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan penilaian'),
            ),
          ],
        ),
      ),
    );
  }

  num get max => widget.answer.question.maxScore;
}
