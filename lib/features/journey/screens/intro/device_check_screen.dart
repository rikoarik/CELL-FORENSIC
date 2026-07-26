import 'package:cell_forensic/ar/ar_capability_probe.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// First screen of the student journey: probes ARCore/camera support (FR-010)
/// and routes healthy devices onto live tabletop AR. Mode 3D is offered only
/// when the probe reports unsupported / permission failure (FR-011).
class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({
    required this.journey,
    this.probe,
    super.key,
  });

  final StudentJourney journey;

  /// Injectable probe for tests; defaults to platform [ArCapabilityProbe].
  final ArCapabilityProbe? probe;

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  late final ArCapabilityProbe _probe =
      widget.probe ?? ArCapabilityProbe();

  bool _checking = true;
  ArCapabilityResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runProbe());
  }

  Future<void> _runProbe() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await _probe.probe(requestCameraPermission: true);
    debugPrint('CellForensic AR probe: $result');
    if (!mounted) return;
    setState(() {
      _result = result;
      _checking = false;
    });
  }

  void _continueLiveAr() {
    widget.journey.completeDeviceCheck(arSupported: true);
  }

  void _continueFallback3d() {
    widget.journey.completeDeviceCheck(arSupported: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final supported = result?.supported == true;
    final webFallback = kIsWeb ||
        result?.reason == 'platform_unsupported' ||
        result?.platform == 'desktop_or_web';

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.journey,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? 560 : double.infinity,
                    ),
                    child: SingleChildScrollView(
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
                            _checking
                                ? 'Memeriksa dukungan Augmented Reality '
                                    '(ARCore / ARKit) dan izin kamera…'
                                : supported
                                ? 'Perangkat mendukung AR. Praktikum akan memakai '
                                    'kamera AR di atas meja laboratorium. Mode 3D '
                                    'hanya dipakai jika sesi AR gagal dimulai.'
                                : webFallback
                                ? 'Browser / desktop tidak menjalankan AR kamera. '
                                    'Kamu tetap bisa mengikuti praktikum dengan '
                                    'Mode 3D pada layar.'
                                : 'Perangkat belum siap untuk AR. Kamu tetap bisa '
                                    'mengikuti praktikum dengan Mode 3D pada layar.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (!_checking && result != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _statusLine(result),
                              key: const Key('device-check-status'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: supported
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          if (_checking)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  key: Key('device-check-loading'),
                                ),
                              ),
                            )
                          else if (supported) ...[
                            Semantics(
                              button: true,
                              label:
                                  'Lanjut dengan mode augmented reality kamera meja',
                              child: FilledButton.icon(
                                key: const Key('device-check-continue-ar'),
                                onPressed: _continueLiveAr,
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text('Lanjut Mode AR'),
                              ),
                            ),
                          ] else ...[
                            Semantics(
                              button: true,
                              label: 'Gunakan Mode 3D tanpa augmented reality',
                              child: FilledButton.icon(
                                key: const Key('device-check-continue-3d'),
                                onPressed: _continueFallback3d,
                                icon: const Icon(Icons.threed_rotation_rounded),
                                label: const Text('Gunakan Mode 3D'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              key: const Key('device-check-retry'),
                              onPressed: _runProbe,
                              child: const Text('Periksa ulang'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _statusLine(ArCapabilityResult result) {
    if (result.supported) {
      return 'Status: AR siap '
          '(${result.arcoreAvailability.isEmpty ? result.reason : result.arcoreAvailability})';
    }
    return switch (result.reason) {
      'camera_permission_denied' =>
        'Status: izin kamera ditolak — aktifkan kamera di pengaturan, lalu periksa ulang.',
      'arcore_unsupported_device' =>
        'Status: perangkat tidak mendukung ARCore.',
      'arkit_unsupported_device' =>
        'Status: perangkat tidak mendukung ARKit.',
      'platform_unsupported' || 'desktop_or_web' =>
        kIsWeb
            ? 'Status: web browser — Mode 3D (AR kamera di Android/iOS).'
            : 'Status: platform ini tidak menjalankan AR kamera.',
      'missing_plugin' =>
        'Status: saluran native AR tidak tersedia (build ulang app).',
      _ => 'Status: AR tidak tersedia (${result.reason}).',
    };
  }
}
