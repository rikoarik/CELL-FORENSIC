import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:cell_forensic/features/journey/journey_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MobileHome extends StatelessWidget {
  const MobileHome({super.key});

  void _openJourney(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const JourneyHost(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? 520 : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 24,
                    vertical: wide ? 40 : 24,
                  ),
                  child: Column(
                    key: Key(
                      wide ? 'student-wide-layout' : 'student-compact-layout',
                    ),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.biotech_rounded,
                            size: 32,
                            color: DesignTokens.navy,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Cell Forensic',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: DesignTokens.navy,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 16),
                        Container(
                          key: const Key('student-web-banner'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: DesignTokens.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.border),
                          ),
                          child: const Text(
                            'Versi web siswa: bergabung ke sesi kelas lewat '
                            'browser. AR kamera meja tersedia di Android/iOS '
                            'native; di sini praktikum memakai Mode 3D.',
                            style: TextStyle(
                              color: DesignTokens.inkMuted,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        Icons.fingerprint_rounded,
                        size: wide ? 96 : 88,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Praktikum forensik sel dalam genggaman.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Masuk ke sesi kelas untuk mengikuti panduan dan '
                        'mencatat hasil pengamatan.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: 'Masuk ke sesi praktikum',
                        child: FilledButton(
                          key: const Key('student-enter-session'),
                          onPressed: () => _openJourney(context),
                          child: const Text('Masuk Sesi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
