import 'package:cell_forensic/features/journey/journey_host.dart';
import 'package:flutter/material.dart';

class MobileHome extends StatelessWidget {
  const MobileHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.biotech_rounded, size: 32),
                  SizedBox(width: 12),
                  Text(
                    'Cell Forensic',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.fingerprint_rounded,
                size: 88,
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
                'Masuk ke sesi kelas untuk mengikuti panduan dan mencatat hasil pengamatan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Masuk ke sesi praktikum',
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const JourneyHost(),
                      ),
                    );
                  },
                  child: const Text('Masuk Sesi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
