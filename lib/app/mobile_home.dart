import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:cell_forensic/features/journey/journey_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MobileHome extends StatelessWidget {
  const MobileHome({super.key});

  Future<void> _openJourneySheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.94,
        minChildSize: 0.8,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) => DecoratedBox(
          decoration: const BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: DesignTokens.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              const Expanded(child: JourneyHost()),
            ],
          ),
        ),
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
                        child: FilledButton.icon(
                          key: const Key('student-enter-session'),
                          onPressed: () => _openJourneySheet(context),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Masuk Sesi'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: FloatingActionButton.extended(
                          key: const Key('student-enter-session-fab'),
                          heroTag: 'student-enter-session-fab',
                          onPressed: () => _openJourneySheet(context),
                          icon: const Icon(Icons.groups_2_rounded),
                          label: const Text('Buka Panel Sesi'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Panel sesi akan muncul penuh agar input kode dan setup kelompok lebih lega.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
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
