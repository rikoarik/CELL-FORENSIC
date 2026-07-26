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

  /// False for unowned demo / other-teacher sessions (E9 RLS).
  final bool canManage;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Future<DashboardGroupDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
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
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(DesignTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sessionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kode sesi: ${widget.session.joinCode}',
                    style: Theme.of(context).textTheme.bodyMedium,
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
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '${m.isLeader ? '★ ' : '• '}${m.displayName}'
                                    '${m.isLeader ? ' (ketua)' : ''}',
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
                                  title: Text(
                                    '${p.missionCode} — ${p.missionTitle}',
                                  ),
                                  subtitle: Text(
                                    'Status: ${_statusLabel(p.status)} · Mode: ${p.arMode}',
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  _SectionCard(
                    title: 'Kesimpulan investigasi',
                    child: detail.conclusion == null
                        ? const Text('Belum ada draft kesimpulan.')
                        : _ConclusionBody(conclusion: detail.conclusion!),
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  Text(
                    'Jawaban & penilaian',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text(
                    detail.pendingReviewCount == 0
                        ? 'Semua jawaban yang membutuhkan review sudah dinilai '
                            '(atau belum ada jawaban esai).'
                        : '${detail.pendingReviewCount} jawaban menunggu review guru.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (!widget.canManage) ...[
                    const SizedBox(height: DesignTokens.spaceSm),
                    Text(
                      'Mode baca saja — sesi ini tidak dapat Anda nilai.',
                      key: const Key('group-detail-readonly'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                  const SizedBox(height: DesignTokens.spaceMd),
                  ..._answerCards(detail),
                ],
              ),
            ),
          );
        },
      ),
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
            canManage: widget.canManage,
            onReview: () => _openReview(answer),
          ),
        ),
    ];
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

class _ConclusionBody extends StatelessWidget {
  const _ConclusionBody({required this.conclusion});

  final DashboardConclusion conclusion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          conclusion.isSubmitted ? 'Status: terkirim' : 'Status: draf',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text('Sampel A: ${conclusion.sampleAIdentity}'),
        Text(conclusion.sampleAReasoning),
        const SizedBox(height: 8),
        Text('Sampel B: ${conclusion.sampleBIdentity}'),
        Text(conclusion.sampleBReasoning),
        const SizedBox(height: 8),
        Text('Hipotesis: ${conclusion.groupHypothesis}'),
      ],
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
