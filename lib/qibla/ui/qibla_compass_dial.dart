import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../home_delivery/ui/theme/prayer_cast_colors.dart';

/// Forest kiblat dial: rose rotates with heading; needle points to Kaaba.
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
                painter: _RosePainter(isId: isId),
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
              painter: const _FixedNotchPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosePainter extends CustomPainter {
  const _RosePainter({required this.isId});

  final bool isId;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(s / 2, s / 2);
    final r = s * 0.46;
    final ring = Paint()
      ..color = PrayerCastColors.mist
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final tick = Paint()
      ..color = PrayerCastColors.mistDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = PrayerCastColors.canopyDeep
      ..style = PaintingStyle.fill;

    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.12, ring);

    for (var i = 0; i < 72; i++) {
      final deg = i * 5.0;
      final rad = (deg - 90) * math.pi / 180;
      final major = i % 9 == 0;
      final inner =
          c +
          Offset(math.cos(rad), math.sin(rad)) * (r * (major ? 0.82 : 0.90));
      final outer = c + Offset(math.cos(rad), math.sin(rad)) * (r * 0.96);
      canvas.drawLine(inner, outer, tick..strokeWidth = major ? 2.0 : 1.1);
    }

    const labelsEn = ['N', 'E', 'S', 'W'];
    const labelsId = ['U', 'T', 'S', 'B'];
    final labels = isId ? labelsId : labelsEn;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 4; i++) {
      final deg = i * 90.0;
      final rad = (deg - 90) * math.pi / 180;
      final pos = c + Offset(math.cos(rad), math.sin(rad)) * (r * 0.68);
      tp.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontFamily: 'AtkinsonHyperlegible',
          fontSize: i == 0 ? 18 : 15,
          fontWeight: FontWeight.w700,
          color: i == 0 ? PrayerCastColors.dawn : PrayerCastColors.mist,
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) =>
      oldDelegate.isId != isId;
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
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(c.dx, c.dy - s * 0.40)
      ..lineTo(c.dx + s * 0.055, c.dy - s * 0.08)
      ..lineTo(c.dx, c.dy - s * 0.14)
      ..lineTo(c.dx - s * 0.055, c.dy - s * 0.08)
      ..close();
    canvas.drawPath(path, p);

    canvas.drawLine(
      Offset(c.dx, c.dy - s * 0.08),
      Offset(c.dx, c.dy + s * 0.28),
      stroke,
    );
    canvas.drawCircle(c, s * 0.035, p);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FixedNotchPainter extends CustomPainter {
  const _FixedNotchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final p = Paint()
      ..color = PrayerCastColors.surfaceRaised
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(s * 0.5, s * 0.018)
      ..lineTo(s * 0.545, s * 0.072)
      ..lineTo(s * 0.455, s * 0.072)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
