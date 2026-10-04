import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../home_delivery/ui/theme/prayer_cast_colors.dart';
import '../../home_delivery/ui/theme/prayer_cast_theme.dart';
import '../../home_delivery/ui/theme/prayer_cast_tokens.dart';

/// Open kiblat dial: rose rotates with heading; needle points to Kaaba.
class QiblaCompassDial extends StatelessWidget {
  const QiblaCompassDial({
    super.key,
    required this.qiblaDeg,
    required this.headingDeg,
    required this.aligned,
    required this.isId,
    this.size = 268,
  });

  final double qiblaDeg;
  final double? headingDeg;
  final bool aligned;
  final bool isId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final heading = headingDeg ?? 0;
    final needleTurn = (qiblaDeg - heading) * math.pi / 180;
    final roseTurn = -heading * math.pi / 180;
    final needleColor = aligned ? PrayerCastColors.leaf : PrayerCastColors.dawn;
    final forest = PrayerCastTokens.isForest(context);
    final ring = forest
        ? PrayerCastColors.mist.withValues(alpha: 0.42)
        : PrayerCastColors.ink.withValues(alpha: 0.38);
    final tick = forest
        ? PrayerCastColors.mist.withValues(alpha: 0.28)
        : PrayerCastColors.ink.withValues(alpha: 0.22);
    final tickMajor = forest
        ? PrayerCastColors.mist.withValues(alpha: 0.72)
        : PrayerCastColors.ink.withValues(alpha: 0.62);
    final cardinal = forest
        ? PrayerCastColors.mist
        : PrayerCastTokens.onSurface(context);
    return Semantics(
      label: isId ? 'Kompas kiblat' : 'Qibla compass',
      value: '${qiblaDeg.round()}',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: roseTurn,
              child: CustomPaint(
                size: Size.square(size),
                painter: _RosePainter(
                  isId: isId,
                  roseTurn: roseTurn,
                  ring: ring,
                  tick: tick,
                  tickMajor: tickMajor,
                  cardinal: cardinal,
                ),
              ),
            ),
            Transform.rotate(
              angle: needleTurn,
              child: CustomPaint(
                size: Size.square(size),
                painter: _NeedlePainter(color: needleColor),
              ),
            ),
            CustomPaint(
              size: Size.square(size),
              painter: _FixedNotchPainter(color: needleColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosePainter extends CustomPainter {
  const _RosePainter({
    required this.isId,
    required this.roseTurn,
    required this.ring,
    required this.tick,
    required this.tickMajor,
    required this.cardinal,
  });

  final bool isId;

  /// Rotation already applied to the whole rose, in radians. Glyphs are
  /// counter-rotated by it so N/E/S/W stay upright and readable.
  final double roseTurn;
  final Color ring;
  final Color tick;
  final Color tickMajor;
  final Color cardinal;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(s / 2, s / 2);
    final r = s * 0.46;
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, r, ringPaint);

    for (var i = 0; i < 36; i++) {
      final deg = i * 10.0;
      final rad = (deg - 90) * math.pi / 180;
      final major = i % 3 == 0;
      final inner =
          c +
          Offset(math.cos(rad), math.sin(rad)) * (r * (major ? 0.86 : 0.92));
      final outer = c + Offset(math.cos(rad), math.sin(rad)) * (r * 0.98);
      tickPaint
        ..color = major ? tickMajor : tick
        ..strokeWidth = major ? 1.6 : 1.0;
      canvas.drawLine(inner, outer, tickPaint);
    }

    const labelsEn = ['N', 'E', 'S', 'W'];
    const labelsId = ['U', 'T', 'S', 'B'];
    final labels = isId ? labelsId : labelsEn;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 4; i++) {
      final deg = i * 90.0;
      final rad = (deg - 90) * math.pi / 180;
      final pos = c + Offset(math.cos(rad), math.sin(rad)) * (r * 0.70);
      tp.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontFamily: PrayerCastTheme.displayFont,
          fontSize: i == 0 ? 18 : 15,
          fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
          color: i == 0 ? PrayerCastColors.dawn : cardinal,
        ),
      );
      tp.layout();
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(-roseTurn);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) =>
      oldDelegate.isId != isId ||
      oldDelegate.roseTurn != roseTurn ||
      oldDelegate.ring != ring ||
      oldDelegate.tick != tick ||
      oldDelegate.tickMajor != tickMajor ||
      oldDelegate.cardinal != cardinal;
}

class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(s / 2, s / 2);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final tail = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final hub = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawLine(
      Offset(c.dx, c.dy + s * 0.04),
      Offset(c.dx, c.dy + s * 0.22),
      tail,
    );

    final path = Path()
      ..moveTo(c.dx, c.dy - s * 0.36)
      ..lineTo(c.dx + s * 0.028, c.dy - s * 0.02)
      ..lineTo(c.dx, c.dy + s * 0.02)
      ..lineTo(c.dx - s * 0.028, c.dy - s * 0.02)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawCircle(c, s * 0.028, hub);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FixedNotchPainter extends CustomPainter {
  const _FixedNotchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(s * 0.5, s * 0.012)
      ..lineTo(s * 0.528, s * 0.048)
      ..lineTo(s * 0.472, s * 0.048)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _FixedNotchPainter oldDelegate) =>
      oldDelegate.color != color;
}
