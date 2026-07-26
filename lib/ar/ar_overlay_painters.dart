import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cell_forensic/ar/ar_overlay_frame.dart';
import 'package:flutter/material.dart';

/// Yellow chloroplast glow (Misi 1) — PDF: yellow glow on shrinking kloroplas.
void paintChloroplastGlow(Canvas canvas, ArOverlayFrame frame) {
  final c = frame.chloroplastCenter;
  final r = frame.modelRadius * 0.48;
  final yellow = const Color(0xFFFACC15);
  final paint = Paint()
    ..shader = RadialGradient(
      colors: [
        yellow.withValues(alpha: 0.75),
        yellow.withValues(alpha: 0.35),
        yellow.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
  canvas.drawCircle(c, r, paint);

  // Soft inner core so the organelle reads as "glowing", not a flat blob.
  canvas.drawCircle(
    c,
    r * 0.35,
    Paint()..color = const Color(0xFFFFF7AE).withValues(alpha: 0.55),
  );
}

/// Deflating vacuole cue (Misi 1 follow-on).
void paintVacuoleDamage(Canvas canvas, ArOverlayFrame frame) {
  final c = frame.vacuoleCenter;
  final r = frame.modelRadius * 0.55;
  final blue = const Color(0xFF38BDF8);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [blue.withValues(alpha: 0.45), blue.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  final ring = Paint()
    ..color = blue.withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  canvas.drawCircle(frame.sampleACenter, frame.modelRadius * 0.72, ring);
  canvas.drawCircle(
    frame.sampleACenter,
    frame.modelRadius * 0.52,
    ring..strokeWidth = 1.5,
  );
}

/// Torn membrane dashed ring (Misi 2).
void paintMembraneDamage(Canvas canvas, ArOverlayFrame frame) {
  _dashedRing(
    canvas,
    frame.sampleACenter,
    frame.membraneRadius,
    const Color(0xFFEF4444),
  );
}

/// Dark-blue water particles spraying from the membrane rim only (Misi 2).
///
/// [t] is 0..1 animation phase. Particles stay near the membrane — never a
/// fullscreen scatter.
void paintWaterLeakParticles(
  Canvas canvas,
  ArOverlayFrame frame, {
  required double t,
}) {
  final origin = frame.sampleACenter;
  final membraneR = frame.membraneRadius;
  // Dark blue (PDF: blue water particle spray — use deep blue, not sky cyan).
  const deepBlue = Color(0xFF1E3A8A);
  const midBlue = Color(0xFF1D4ED8);

  // Leak vents along the lower-right membrane arc (torn region).
  const vents = <double>[
    math.pi * 0.15,
    math.pi * 0.35,
    math.pi * 0.55,
    math.pi * 0.75,
    math.pi * 0.95,
  ];

  for (var v = 0; v < vents.length; v++) {
    final baseAngle = vents[v];
    for (var i = 0; i < 4; i++) {
      final phase = (t + v * 0.13 + i * 0.07) % 1.0;
      final travel = membraneR * (0.05 + phase * 0.55);
      final angle = baseAngle + math.sin(t * math.pi * 2 + i) * 0.08;
      final p = origin.translate(
        math.cos(angle) * (membraneR + travel),
        math.sin(angle) * (membraneR + travel * 0.85) + phase * membraneR * 0.15,
      );
      final size = 3.0 + (1 - phase) * 5.0 + (i % 2);
      final alpha = (1 - phase) * 0.85;
      canvas.drawOval(
        Rect.fromCenter(center: p, width: size * 0.7, height: size),
        Paint()
          ..color = (i.isEven ? deepBlue : midBlue).withValues(alpha: alpha),
      );
    }
  }
}

/// Green cell-wall contour / outline on Sample A (Misi 3).
void paintCellWallContour(Canvas canvas, ArOverlayFrame frame) {
  final c = frame.sampleACenter;
  final r = frame.membraneRadius;
  const green = Color(0xFF22C55E);

  // Outer glow fringe (subtle) + sharp contour stroke.
  canvas.drawCircle(
    c,
    r * 1.08,
    Paint()
      ..shader = RadialGradient(
        colors: [
          green.withValues(alpha: 0),
          green.withValues(alpha: 0.2),
          green.withValues(alpha: 0),
        ],
        stops: const [0.7, 0.92, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.08)),
  );

  final contour = Paint()
    ..color = green.withValues(alpha: 0.95)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;
  canvas.drawCircle(c, r, contour);

  // Inner parallel contour so it reads as "dinding sel" thickness.
  canvas.drawCircle(
    c,
    r * 0.92,
    Paint()
      ..color = green.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

/// Red X over Sample B (Misi 3) — "tidak ada dinding sel".
void paintMissingStructureCross(Canvas canvas, ArOverlayFrame frame) {
  final c = frame.sampleBCenter;
  final size = frame.modelRadius * 0.55;
  final paint = Paint()
    ..color = const Color(0xFFEF4444)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(c.translate(-size, -size), c.translate(size, size), paint);
  canvas.drawLine(c.translate(size, -size), c.translate(-size, size), paint);

  // Soft red halo so the mark stays readable on dark fallback / AR camera.
  canvas.drawCircle(
    c,
    size * 1.15,
    Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6,
  );

  paintOverlayLabel(
    canvas,
    c.translate(0, frame.modelRadius * 0.85),
    'Tidak ada dinding sel',
  );
}

/// Force / pressure arrows around Sample A (Misi 3) — wall resists force.
void paintForceArrows(Canvas canvas, ArOverlayFrame frame) {
  final c = frame.sampleACenter;
  final r = frame.modelRadius;
  const amber = Color(0xFFF59E0B);
  final paint = Paint()
    ..color = amber
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  // Eight radial inward arrows (external force → wall).
  for (var i = 0; i < 8; i++) {
    final angle = (i / 8) * math.pi * 2;
    final outer = c.translate(
      math.cos(angle) * r * 1.55,
      math.sin(angle) * r * 1.55,
    );
    final inner = c.translate(
      math.cos(angle) * r * 1.08,
      math.sin(angle) * r * 1.08,
    );
    canvas.drawLine(outer, inner, paint);
    _arrowHead(canvas, outer, inner, paint);
  }

  // Also mark Sample B weakly so comparison remains readable when dual.
  if (frame.dualSamples) {
    final b = frame.sampleBCenter;
    final soft = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    // Outward arrows — no wall, force wins / cell collapses cue.
    for (final dir in [-1.0, 1.0]) {
      final start = b.translate(dir * r * 0.15, 0);
      final end = b.translate(dir * r * 1.1, 0);
      canvas.drawLine(start, end, soft);
      _arrowHead(canvas, start, end, soft);
    }
  }
}

/// Side-by-side sample labels (Misi 3).
void paintComparisonLabels(Canvas canvas, ArOverlayFrame frame) {
  paintOverlayLabel(
    canvas,
    frame.sampleACenter.translate(0, -frame.modelRadius * 1.15),
    'Sampel A',
  );
  paintOverlayLabel(
    canvas,
    frame.sampleBCenter.translate(0, -frame.modelRadius * 1.15),
    'Sampel B',
  );
}

void paintOverlayLabel(Canvas canvas, Offset c, String text) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 11),
  )
    ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF), fontSize: 11))
    ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 140));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c,
        width: paragraph.maxIntrinsicWidth + 14,
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

void _arrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;
  final ux = dx / len;
  final uy = dy / len;
  const head = 10.0;
  final left = Offset(
    to.dx - ux * head - uy * head * 0.55,
    to.dy - uy * head + ux * head * 0.55,
  );
  final right = Offset(
    to.dx - ux * head + uy * head * 0.55,
    to.dy - uy * head - ux * head * 0.55,
  );
  canvas.drawLine(to, left, paint);
  canvas.drawLine(to, right, paint);
}
