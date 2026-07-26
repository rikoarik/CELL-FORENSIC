import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';

/// First screen of the student journey: checks whether the device supports AR
/// (FR-010/011) and lets the group pick between the AR experience or the 3D
/// fallback before joining a session.
class DeviceCheckScreen extends StatelessWidget {
  const DeviceCheckScreen({required this.journey, super.key});

  final StudentJourney journey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: journey,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.view_in_ar_rounded,
                    size: 72,
                    color: theme.colorScheme.secondary,
                    semanticLabel: 'Ikon augmented reality',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pemeriksaan Perangkat',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sebelum mulai, kami memeriksa apakah perangkatmu '
                    'mendukung Augmented Reality (AR). Dengan AR, kamu bisa '
                    'melihat model sel seolah berada di atas meja. Jika '
                    'perangkat belum mendukung AR, kamu tetap bisa mengikuti '
                    'praktikum memakai Mode 3D pada layar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    button: true,
                    label: 'AR Didukung, lanjut dengan mode augmented reality',
                    child: FilledButton.icon(
                      onPressed: () =>
                          journey.completeDeviceCheck(arSupported: true),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('AR Didukung'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: 'Gunakan Mode 3D tanpa augmented reality',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 52),
                      ),
                      onPressed: () =>
                          journey.completeDeviceCheck(arSupported: false),
                      icon: const Icon(Icons.threed_rotation_rounded),
                      label: const Text('Gunakan Mode 3D'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
