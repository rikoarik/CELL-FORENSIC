import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';

/// Compact progress strip so the student always sees where they are in the
/// single end-to-end flow (investigasi → kesimpulan → POS → hasil).
///
/// Doubles as the stage title so child screens don't need a second AppBar
/// (avoids the stacked top chrome that felt like "item atas-bawah").
class JourneyProgressBar extends StatelessWidget {
  const JourneyProgressBar({required this.journey, super.key});

  final StudentJourney journey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, subtitle, value) = _progress(journey);

    return Semantics(
      label: '$title. $subtitle',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (journey.canGoBack)
                  IconButton(
                    key: const Key('journey-back-button'),
                    tooltip: 'Kembali',
                    onPressed: journey.goBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${(value * 100).round()}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: value, minHeight: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (String, String, double) _progress(StudentJourney journey) {
    return switch (journey.stage) {
      JourneyStage.deviceCheck => (
        'Pemeriksaan Perangkat',
        'Pilih Mode AR atau Mode 3D',
        0.05,
      ),
      JourneyStage.joinSession => (
        'Bergabung ke Sesi',
        'Masukkan kode sesi',
        0.08,
      ),
      JourneyStage.groupSetup => (
        'Siapkan Kelompok',
        journey.groupName == null
            ? 'Buat kelompok dan ketua'
            : 'Kelola anggota · ${journey.groupName}',
        0.12,
      ),
      JourneyStage.onboarding => (
        'Panduan Singkat',
        journey.arSupported ? 'Mode AR' : 'Mode 3D Viewer',
        0.15,
      ),
      JourneyStage.investigating => (
        journey.arSupported ? 'Investigasi AR' : 'Investigasi 3D',
        journey.labPlaced
            ? (journey.runningMissionNumber != null
                  ? journey.activeMission.title
                  : 'Lab siap · tanya asisten untuk misi')
            : 'Scene 1 · pindai meja laboratorium',
        0.15 +
            (journey.missionProgress.values
                        .where((p) => p.isCompleted)
                        .length /
                    journey.missionCount.clamp(1, 99)) *
                0.45,
      ),
      JourneyStage.conclusion => (
        'Kesimpulan Investigasi',
        'Rangkum temuan kelompok',
        0.65,
      ),
      JourneyStage.stations => (
        'Stasiun Evaluasi (POS)',
        'POS ${journey.stationIndex + 1} dari ${journey.stationCount}',
        0.70 + ((journey.stationIndex + 0.5) / journey.stationCount) * 0.25,
      ),
      JourneyStage.results => ('Hasil Praktikum', 'Selesai', 1.0),
    };
  }
}
