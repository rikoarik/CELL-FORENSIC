import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';

/// Third screen of the student journey: a short tutorial explaining the core
/// interactions (scan, placement, ask the AI, logbook, reset) before starting
/// the investigation.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({required this.journey, super.key});

  final StudentJourney journey;

  List<_TutorialStep> _stepsFor(bool arSupported) => [
    _TutorialStep(
      icon: arSupported
          ? Icons.view_in_ar_rounded
          : Icons.threed_rotation_rounded,
      title: arSupported ? 'Pindai Permukaan' : 'Buka Model 3D',
      description: arSupported
          ? 'Arahkan kamera ke meja atau permukaan datar hingga bidang '
                'terdeteksi, lalu ketuk untuk menempatkan model sel.'
          : 'Model sel tampil di layar. Seret untuk memutar dan cubit untuk '
                'memperbesar tanpa kamera AR.',
    ),
    _TutorialStep(
      icon: Icons.play_circle_outline_rounded,
      title: 'Jalankan Langkah',
      description:
          'Tekan "Jalankan Langkah" untuk memutar sequence misi. Tiap '
          'langkah bisa mengganti fokusatan atau model organel.',
    ),
    _TutorialStep(
      icon: Icons.smart_toy_rounded,
      title: 'Tanya AI',
      description:
          'Bingung? Ketik pertanyaan ke asisten AI, misalnya "amati organel '
          'sampel A", untuk mendapat petunjuk.',
    ),
    _TutorialStep(
      icon: Icons.menu_book_rounded,
      title: 'Isi Logbook',
      description:
          'Catat hasil pengamatan tiap misi pada logbook. Jawaban tersimpan '
          'otomatis di perangkat.',
    ),
    _TutorialStep(
      icon: Icons.flag_rounded,
      title: 'Selesaikan Misi',
      description:
          'Setelah seluruh langkah sequence selesai, tekan "Selesaikan '
          'Misi" untuk lanjut ke misi berikutnya, kesimpulan, lalu POS.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: journey,
          builder: (context, _) {
            final steps = _stepsFor(journey.arSupported);
            final modeLabel = journey.arSupported
                ? 'Mode AR'
                : 'Mode 3D Viewer';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Panduan Singkat',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kelompok ${journey.groupName ?? ''} · $modeLabel. '
                        'Kenali lima langkah dasar sebelum mulai investigasi.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: steps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _TutorialTile(step: steps[index], number: index + 1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Semantics(
                    button: true,
                    label: 'Mulai investigasi praktikum',
                    child: FilledButton.icon(
                      onPressed: journey.finishOnboarding,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Mulai Investigasi'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _TutorialTile extends StatelessWidget {
  const _TutorialTile({required this.step, required this.number});

  final _TutorialStep step;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Langkah $number, ${step.title}. ${step.description}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.secondary.withValues(
                  alpha: 0.12,
                ),
                child: Icon(step.icon, color: theme.colorScheme.secondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(step.description, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
