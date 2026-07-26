import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';

/// Final results screen for the student journey.
///
/// Shows the auto-scored objective total ([StudentJourney.objectiveScore]) and,
/// when [StudentJourney.pendingTeacherReview] is true, a note that essay
/// answers are still awaiting teacher assessment. Closes with a completion
/// message.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({required this.journey, super.key});

  final StudentJourney journey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = journey.objectiveScore;
    final pending = journey.pendingTeacherReview;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.verified_rounded,
                size: 72,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Praktikum selesai!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Terima kasih sudah menyelesaikan seluruh stasiun evaluasi. '
                'Kerja bagus, tim!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Stasiun terkunci: ${journey.submittedStationCodes.length} dari '
                '${journey.stationCount}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Skor objektif otomatis $score poin',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Skor Objektif (Otomatis)',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$score poin',
                          style: theme.textTheme.displaySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (pending) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: 'Jawaban esai masih menunggu penilaian dari guru',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.hourglass_top_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Jawaban esai kelompokmu masih menunggu penilaian '
                            'dari guru. Skor akhir akan mencakup nilai esai '
                            'setelah diperiksa.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
