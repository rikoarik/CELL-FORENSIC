import 'package:cell_forensic/ar/ar_overlay_frame.dart';
import 'package:cell_forensic/ar/ar_overlay_painters.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:flutter/material.dart';

/// Flutter overlays anchored to the model frame (E10 Wave 2 / E11).
///
/// Used when `ar_flutter_plugin_2` lacks particle emitters / material glow.
/// Bound to Sample A / Sample B via [ArOverlayFrame] — not fullscreen effects.
class ArSceneOverlayLayer extends StatefulWidget {
  const ArSceneOverlayLayer({
    required this.effect,
    required this.highlightTarget,
    this.opacity = 1,
    this.dualSamples = false,
    super.key,
  });

  final ArOverlayEffect effect;
  final String? highlightTarget;
  final double opacity;

  /// When true, Sample A is left and Sample B is right (Misi 3 comparison).
  final bool dualSamples;

  @override
  State<ArSceneOverlayLayer> createState() => _ArSceneOverlayLayerState();
}

class _ArSceneOverlayLayerState extends State<ArSceneOverlayLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  bool get _needsTicker =>
      widget.effect == ArOverlayEffect.waterLeak ||
      widget.effect == ArOverlayEffect.chloroplastHighlight ||
      widget.effect == ArOverlayEffect.forceArrows;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ArSceneOverlayLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    if (_needsTicker) {
      if (!_pulse.isAnimating) {
        _pulse.repeat();
      }
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.effect == ArOverlayEffect.none &&
        widget.highlightTarget == null) {
      return const SizedBox.shrink(key: Key('ar-overlay-empty'));
    }

    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity.clamp(0.35, 1.0),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            return CustomPaint(
              painter: _ArOverlayPainter(
                effect: widget.effect,
                highlightTarget: widget.highlightTarget,
                dualSamples: widget.dualSamples,
                t: _pulse.value,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _ArOverlayPainter extends CustomPainter {
  _ArOverlayPainter({
    required this.effect,
    required this.highlightTarget,
    required this.dualSamples,
    required this.t,
  });

  final ArOverlayEffect effect;
  final String? highlightTarget;
  final bool dualSamples;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = ArOverlayFrame(size: size, dualSamples: dualSamples);

    switch (effect) {
      case ArOverlayEffect.chloroplastHighlight:
        paintChloroplastGlow(canvas, frame);
      case ArOverlayEffect.vacuoleDamage:
        paintVacuoleDamage(canvas, frame);
      case ArOverlayEffect.membraneDamage:
        paintMembraneDamage(canvas, frame);
      case ArOverlayEffect.waterLeak:
        paintMembraneDamage(canvas, frame);
        paintWaterLeakParticles(canvas, frame, t: t);
      case ArOverlayEffect.cellWallHighlight:
        paintCellWallContour(canvas, frame);
      case ArOverlayEffect.missingStructureCross:
        if (dualSamples) {
          paintComparisonLabels(canvas, frame);
        }
        paintMissingStructureCross(canvas, frame);
      case ArOverlayEffect.forceArrows:
        if (dualSamples) {
          paintComparisonLabels(canvas, frame);
          paintCellWallContour(canvas, frame);
        }
        paintForceArrows(canvas, frame);
      case ArOverlayEffect.comparisonLabels:
        paintComparisonLabels(canvas, frame);
      case ArOverlayEffect.none:
        break;
    }

    // Tap-organelle highlight (UI stand-in for mesh pick) — yellow kloroplas.
    if (highlightTarget == ArNodeIds.chloroplast &&
        effect != ArOverlayEffect.chloroplastHighlight) {
      paintChloroplastGlow(canvas, frame);
    }

    if (highlightTarget == ArNodeIds.cellWall &&
        effect != ArOverlayEffect.cellWallHighlight) {
      paintCellWallContour(canvas, frame);
    }

    if (highlightTarget == ArNodeIds.membrane &&
        effect != ArOverlayEffect.membraneDamage &&
        effect != ArOverlayEffect.waterLeak) {
      paintMembraneDamage(canvas, frame);
    }
  }

  @override
  bool shouldRepaint(covariant _ArOverlayPainter oldDelegate) {
    return oldDelegate.effect != effect ||
        oldDelegate.highlightTarget != highlightTarget ||
        oldDelegate.dualSamples != dualSamples ||
        oldDelegate.t != t;
  }
}
