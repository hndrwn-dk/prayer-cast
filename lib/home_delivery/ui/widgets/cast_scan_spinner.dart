import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/prayer_cast_colors.dart';

/// Google Cast–style discovery spinner: rotating arc on a soft track, optional pulse.
///
/// Not [CircularProgressIndicator] — CustomPainter animation tuned for Prayer Cast
/// forest green / mist.
class CastScanSpinner extends StatefulWidget {
  const CastScanSpinner({
    super.key,
    this.size = 36,
    this.strokeWidth,
    this.color = PrayerCastColors.canopy,
    this.trackColor,
    this.pulse = true,
  });

  final double size;
  final double? strokeWidth;
  final Color color;
  final Color? trackColor;
  final bool pulse;

  @override
  State<CastScanSpinner> createState() => _CastScanSpinnerState();
}

class _CastScanSpinnerState extends State<CastScanSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stroke = widget.strokeWidth ?? (widget.size >= 28 ? 3.0 : 2.2);
    final track = widget.trackColor ??
        PrayerCastColors.mistDeep.withValues(alpha: 0.55);

    return Semantics(
      label: 'Scanning',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _CastScanSpinnerPainter(
                progress: _controller.value,
                color: widget.color,
                trackColor: track,
                strokeWidth: stroke,
                pulse: widget.pulse,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CastScanSpinnerPainter extends CustomPainter {
  _CastScanSpinnerPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.pulse,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Soft mist track; optional breath so empty-state scan feels alive.
    final trackAlpha = pulse
        ? 0.35 + 0.25 * (0.5 + 0.5 * math.sin(progress * math.pi * 2))
        : 0.55;
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: trackAlpha.clamp(0.2, 0.7))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Sweeping arc (~100°) rotating like Cast discovery.
    const sweep = math.pi * 0.55;
    final start = progress * math.pi * 2 - math.pi / 2;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, arcPaint);

    // Leading tip highlight for a bit of Google-like polish.
    final tipAngle = start + sweep;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      strokeWidth * 0.55,
      Paint()..color = color.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _CastScanSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.pulse != pulse;
  }
}
