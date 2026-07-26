import 'package:cell_forensic/ar/ar_overlay_frame.dart';
import 'package:cell_forensic/ar/organelle_hotspot.dart';
import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';

/// Flutter hit-targets + glow over Sample A (mesh pick unavailable).
///
/// Positions use [ArOverlayFrame] organelle anchors so live AR and ModelViewer
/// share the same relative layout. Observation popup lives outside this layer
/// (see [OrganelleObservationSheet]) so it is not clipped by the scene viewport.
class OrganelleHotspotLayer extends StatelessWidget {
  const OrganelleHotspotLayer({
    required this.controller,
    required this.dualSamples,
    super.key,
  });

  final OrganelleHotspotController controller;
  final bool dualSamples;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.enabled) {
          return const SizedBox.shrink(key: Key('organelle-hotspots-disabled'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final frame = ArOverlayFrame(size: size, dualSamples: dualSamples);
            final compact = size.shortestSide < 360 || size.height < 240;

            return Stack(
              key: const Key('organelle-hotspot-layer'),
              fit: StackFit.expand,
              children: [
                ..._selectionGlows(frame),
                if (controller.introVisible)
                  _IntroBanner(
                    compact: compact,
                    onDismiss: controller.dismissIntro,
                  ),
                // Hit targets above intro so organelle taps are not blocked.
                ..._hitTargets(frame),
              ],
            );
          },
        );
      },
    );
  }

  Offset _anchorFor(OrganelleHotspotId id, ArOverlayFrame frame) =>
      switch (id) {
        OrganelleHotspotId.plantCell => frame.sampleACenter,
        OrganelleHotspotId.chloroplast => frame.chloroplastCenter,
        OrganelleHotspotId.vacuole => frame.vacuoleCenter,
      };

  List<Widget> _hitTargets(ArOverlayFrame frame) {
    final rCell = frame.modelRadius * 0.95;
    final rChloro = frame.modelRadius * 0.36;
    final rVac = frame.modelRadius * 0.42;
    final chloro2 = frame.sampleACenter.translate(
      -frame.modelRadius * 0.42,
      frame.modelRadius * 0.36,
    );

    return [
      // Whole cell under organelle discs — organelle taps win overlaps.
      _HotspotTarget(
        key: const Key('hotspot-plant-cell'),
        center: frame.sampleACenter,
        radius: rCell,
        label: SampleAOrganelleHotspots.plantCell.semanticsLabel,
        phase: controller.phaseOf(OrganelleHotspotId.plantCell),
        onTap: () => controller.select(OrganelleHotspotId.plantCell),
      ),
      _HotspotTarget(
        key: const Key('hotspot-vacuole'),
        center: frame.vacuoleCenter,
        radius: rVac,
        label: SampleAOrganelleHotspots.vacuole.semanticsLabel,
        phase: controller.phaseOf(OrganelleHotspotId.vacuole),
        onTap: () => controller.select(OrganelleHotspotId.vacuole),
      ),
      _HotspotTarget(
        key: const Key('hotspot-chloroplast'),
        center: frame.chloroplastCenter,
        radius: rChloro,
        label: SampleAOrganelleHotspots.chloroplast.semanticsLabel,
        phase: controller.phaseOf(OrganelleHotspotId.chloroplast),
        onTap: () => controller.select(OrganelleHotspotId.chloroplast),
      ),
      _HotspotTarget(
        key: const Key('hotspot-chloroplast-secondary'),
        center: chloro2,
        radius: rChloro * 0.85,
        label: SampleAOrganelleHotspots.chloroplast.semanticsLabel,
        phase: controller.phaseOf(OrganelleHotspotId.chloroplast),
        onTap: () => controller.select(OrganelleHotspotId.chloroplast),
      ),
    ];
  }

  List<Widget> _selectionGlows(ArOverlayFrame frame) {
    final selected = controller.selectedId;
    if (selected == null) return const [];
    final center = _anchorFor(selected, frame);
    final radius = switch (selected) {
      OrganelleHotspotId.plantCell => frame.modelRadius * 1.05,
      OrganelleHotspotId.vacuole => frame.modelRadius * 0.5,
      OrganelleHotspotId.chloroplast => frame.modelRadius * 0.42,
    };
    final color = switch (selected) {
      OrganelleHotspotId.plantCell => const Color(0xFFFACC15),
      OrganelleHotspotId.vacuole => const Color(0xFF38BDF8),
      OrganelleHotspotId.chloroplast => const Color(0xFFFACC15),
    };

    return [
      IgnorePointer(
        child: CustomPaint(
          key: Key('hotspot-glow-${selected.name}'),
          painter: _HotspotGlowPainter(
            center: center,
            radius: radius,
            color: color,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ];
  }
}

/// Observation sheet placed **outside** the AR viewport (panel column).
///
/// Keeps live AR mostly visible and avoids scroll-clip of in-scene popups.
class OrganelleObservationSheet extends StatelessWidget {
  const OrganelleObservationSheet({
    required this.controller,
    this.onAskAi,
    this.onLogbook,
    super.key,
  });

  final OrganelleHotspotController controller;
  final ValueChanged<OrganelleHotspotContent>? onAskAi;
  final ValueChanged<OrganelleHotspotContent>? onLogbook;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final id = controller.openPopupId;
        if (id == null) {
          return const SizedBox.shrink(key: Key('organelle-popup-closed'));
        }
        final content = SampleAOrganelleHotspots.contentFor(id);
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Material(
            key: Key('organelle-popup-${content.id.name}'),
            color: Colors.white.withValues(alpha: 0.98),
            elevation: 2,
            shadowColor: DesignTokens.navy.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                border: Border.all(color: DesignTokens.border),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          content.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: DesignTokens.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('organelle-popup-close'),
                        tooltip: 'Tutup',
                        visualDensity: VisualDensity.compact,
                        onPressed: controller.closePopup,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                  Text(
                    content.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: DesignTokens.inkMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonal(
                        key: const Key('organelle-popup-ask-ai'),
                        onPressed: () {
                          onAskAi?.call(content);
                          controller.closePopup();
                        },
                        style: FilledButton.styleFrom(
                          foregroundColor: DesignTokens.navy,
                          backgroundColor:
                              DesignTokens.blue.withValues(alpha: 0.12),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Tanya AI'),
                      ),
                      OutlinedButton(
                        key: const Key('organelle-popup-logbook'),
                        onPressed: () {
                          controller.markInspected(content.id);
                          onLogbook?.call(content);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DesignTokens.navy,
                          side: const BorderSide(color: DesignTokens.border),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Catat di Logbook'),
                      ),
                      TextButton(
                        key: const Key('organelle-popup-tutup'),
                        onPressed: controller.closePopup,
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HotspotTarget extends StatelessWidget {
  const _HotspotTarget({
    required this.center,
    required this.radius,
    required this.label,
    required this.phase,
    required this.onTap,
    super.key,
  });

  final Offset center;
  final double radius;
  final String label;
  final OrganelleHotspotPhase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final diameter = (radius * 2).clamp(DesignTokens.touchMin, 120.0);
    return Positioned(
      left: center.dx - diameter / 2,
      top: center.dy - diameter / 2,
      width: diameter,
      height: diameter,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DesignTokens.blue.withValues(alpha: 0.01),
              border: phase == OrganelleHotspotPhase.selected
                  ? Border.all(color: DesignTokens.blue, width: 2)
                  : phase == OrganelleHotspotPhase.inspected
                      ? Border.all(
                          color: DesignTokens.blue.withValues(alpha: 0.35),
                          width: 1.5,
                        )
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _HotspotGlowPainter extends CustomPainter {
  _HotspotGlowPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  final Offset center;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * 0.92,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _HotspotGlowPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.compact, required this.onDismiss});

  final bool compact;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceSm),
        child: Material(
          key: const Key('organelle-intro-hint'),
          color: Colors.white.withValues(alpha: 0.94),
          elevation: 2,
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: compact ? double.infinity : 340,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SampleAOrganelleHotspots.intro.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: DesignTokens.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          compact
                              ? 'Cell tumbuhan mengalami krisis turgor. '
                                  'Ketuk sel/organel yang rusak.'
                              : SampleAOrganelleHotspots.intro.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: DesignTokens.inkMuted,
                            height: 1.35,
                          ),
                          maxLines: compact ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          SampleAOrganelleHotspots.intro.instruction,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: DesignTokens.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('organelle-intro-dismiss'),
                    tooltip: 'Tutup',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
