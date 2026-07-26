import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:flutter/material.dart';

/// Flutter overlays anchored to the model frame (E11).
///
/// Used when `ar_flutter_plugin_2` lacks particle emitters / material glow.
class ArSceneOverlayLayer extends StatelessWidget {
  const ArSceneOverlayLayer({
    required this.effect,
    required this.highlightTarget,
    this.opacity = 1,
    super.key,
  });

  final ArOverlayEffect effect;
  final String? highlightTarget;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (effect == ArOverlayEffect.none && highlightTarget == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.35, 1.0),
        child: CustomPaint(
          painter: _ArOverlayPainter(
            effect: effect,
            highlightTarget: highlightTarget,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ArOverlayPainter extends CustomPainter {
  _ArOverlayPainter({required this.effect, required this.highlightTarget});

  final ArOverlayEffect effect;
  final String? highlightTarget;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final modelRadius = size.shortestSide * 0.22;

    switch (effect) {
      case ArOverlayEffect.chloroplastHighlight:
        _glow(
          canvas,
          center.translate(-modelRadius * 0.25, 0),
          modelRadius * 0.45,
          const Color(0xFF22C55E),
        );
      case ArOverlayEffect.vacuoleDamage:
        _glow(
          canvas,
          center.translate(modelRadius * 0.2, modelRadius * 0.1),
          modelRadius * 0.5,
          const Color(0xFF38BDF8),
        );
        _shrinkRing(canvas, center, modelRadius * 0.7);
      case ArOverlayEffect.membraneDamage:
        _dashedRing(canvas, center, modelRadius, const Color(0xFFEF4444));
      case ArOverlayEffect.waterLeak:
        // PDF Misi 2: dark-blue water spheres spray OUT from the membrane
        // region — not a fullscreen particle field.
        final membraneOrigin = highlightTarget == ArNodeIds.membrane
            ? center.translate(0, -modelRadius * 0.05)
            : center.translate(0, modelRadius * 0.05);
        _membraneWaterSpray(
          canvas,
          membraneOrigin,
          modelRadius,
        );
      case ArOverlayEffect.cellWallHighlight:
        _glow(canvas, center, modelRadius * 1.05, const Color(0xFFFBBF24));
      case ArOverlayEffect.missingStructureCross:
        _cross(
          canvas,
          center.translate(modelRadius * 1.35, 0),
          modelRadius * 0.35,
        );
        _label(
          canvas,
          center.translate(modelRadius * 1.35, modelRadius * 0.55),
          'Tidak ada dinding sel',
        );
      case ArOverlayEffect.forceArrows:
        _arrows(canvas, center, modelRadius);
      case ArOverlayEffect.comparisonLabels:
        _label(
          canvas,
          center.translate(-modelRadius * 1.1, -modelRadius),
          'Sampel A',
        );
        _label(
          canvas,
          center.translate(modelRadius * 1.1, -modelRadius),
          'Sampel B',
        );
      case ArOverlayEffect.none:
        break;
    }

    if (highlightTarget == ArNodeIds.chloroplast &&
        effect != ArOverlayEffect.chloroplastHighlight) {
      _glow(
        canvas,
        center.translate(-modelRadius * 0.25, 0),
        modelRadius * 0.4,
        const Color(0xFF22C55E),
      );
    }
    if (highlightTarget == ArNodeIds.membrane &&
        effect != ArOverlayEffect.membraneDamage &&
        effect != ArOverlayEffect.waterLeak) {
      _dashedRing(
        canvas,
        center,
        modelRadius * 0.95,
        const Color(0xFF60A5FA),
      );
    }
  }

  /// Dark-blue (#1E3A8A family) droplets exiting radially from the membrane
  /// rim — kept inside ~1.4× model radius so the spray stays tabletop-local.
  void _membraneWaterSpray(Canvas canvas, Offset membraneCenter, double r) {
    const darkBlue = Color(0xFF1E3A8A);
    final fill = Paint()..color = darkBlue.withValues(alpha: 0.88);
    final rim = Paint()
      ..color = const Color(0xFF1E40AF).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Soft membrane rim so particles read as "from membrane", not HUD-wide.
    canvas.drawCircle(membraneCenter, r * 0.92, rim);

    const count = 14;
    for (var i = 0; i < count; i++) {
      final t = i / count;
      final angle = -math.pi * 0.15 + t * math.pi * 1.3;
      final dist = r * (0.95 + (i % 4) * 0.12);
      final pos = membraneCenter.translate(
        math.cos(angle) * dist,
        math.sin(angle) * dist + r * 0.08 * (i % 3),
      );
      final size = 5.0 + (i % 4);
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: size, height: size * 1.35),
        fill,
      );
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  void _shrinkRing(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c, r * 0.72, paint..strokeWidth = 1.5);
  }

  void _dashedRing(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const dash = 10.0;
    const gap = 6.0;
    var angle = 0.0;
    while (angle < math.pi * 2) {
      final next = angle + dash / r;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        angle,
        next - angle,
        false,
        paint,
      );
      angle = next + gap / r;
    }
  }

  void _cross(Canvas canvas, Offset c, double size) {
    final paint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-size, -size), c.translate(size, size), paint);
    canvas.drawLine(c.translate(size, -size), c.translate(-size, size), paint);
  }

  void _arrows(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final dir in [-1.0, 1.0]) {
      final start = c.translate(dir * r * 0.2, -r * 0.1);
      final end = c.translate(dir * r * 1.2, -r * 0.1);
      canvas.drawLine(start, end, paint);
      canvas.drawLine(end, end.translate(-dir * 12, -8), paint);
      canvas.drawLine(end, end.translate(-dir * 12, 8), paint);
    }
  }

  void _label(Canvas canvas, Offset c, String text) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 11),
    )
      ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF), fontSize: 11))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 120));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c,
          width: paragraph.maxIntrinsicWidth + 12,
          height: paragraph.height + 8,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.black54,
    );
    canvas.drawParagraph(
      paragraph,
      Offset(
        c.dx - paragraph.maxIntrinsicWidth / 2,
        c.dy - paragraph.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ArOverlayPainter oldDelegate) {
    return oldDelegate.effect != effect ||
        oldDelegate.highlightTarget != highlightTarget;
  }
}
