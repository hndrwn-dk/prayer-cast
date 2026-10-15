import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';

/// Hand-drawn vector icons — premium stroke language, not stock Material glyphs.
abstract final class PremiumIcons {
  static Widget speaker({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintSpeaker);

  static Widget tv({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintTv);

  static Widget check({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintCheck);

  static Widget trash({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintTrash);

  static Widget refresh({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintRefresh);

  static Widget moon({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintMoon);

  static Widget clock({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintClock);

  static Widget caretLeft({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintCaretLeft);

  static Widget caretRight({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintCaretRight);

  static Widget info({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintInfo);

  static Widget batteryWarning({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintBattery);

  static Widget gear({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintGear);

  static Widget house({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintHouse);

  static Widget devices({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintDevices);

  /// Single handset — phone delivery / onboarding audio choice.
  static Widget phone({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintPhone);

  static Widget speakerSlash({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintSpeakerSlash);

  static Widget wifiSlash({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintWifiSlash);

  static Widget plug({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintPlug);

  static Widget musicMinus({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintMusicMinus);

  static Widget moonStars({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintMoonStars);

  static Widget sun({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintSun);

  static Widget sunrise({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintSunrise);

  static Widget sunAfternoon({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintSunAfternoon);

  static Widget sunset({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintSunset);

  /// Canonical prayer (`fajr` / `dhuhr` / `asr` / `maghrib` / `isha`).
  static Widget forPrayer(String prayer, {double size = 24, Color? color}) {
    switch (prayer) {
      case 'fajr':
        return sunrise(size: size, color: color);
      case 'dhuhr':
        return sun(size: size, color: color);
      case 'asr':
        return sunAfternoon(size: size, color: color);
      case 'maghrib':
        return sunset(size: size, color: color);
      case 'isha':
        return moon(size: size, color: color);
      default:
        return clock(size: size, color: color);
    }
  }

  static Widget prohibit({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintProhibit);

  /// Coffee cup (legacy Ko-fi mark; unused by support UI).
  static Widget coffee({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintCoffee);

  /// Stacked lines — delivery attempt history.
  static Widget logLines({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintLogLines);

  /// Three vertical bars — period stats.
  static Widget bars({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintBars);

  static Widget trendUp({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintTrendUp);

  static Widget alertCircle({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintAlertCircle);

  static Widget flame({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintFlame);

  static Widget prayerTimes({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintPrayerTimes);

  static Widget prayerTracker({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintPrayerTracker);

  static Widget qibla({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintQibla);

  static Widget morningAdhkar({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintMorningAdhkar);

  static Widget eveningAdhkar({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintEveningAdhkar);

  static Widget tasbih({double size = 24, Color? color}) =>
      _Icon(size: size, color: color, paint: _paintTasbih);
}

typedef _PaintFn = void Function(Canvas canvas, Size size, Color color);

class _Icon extends StatelessWidget {
  const _Icon({required this.size, required this.paint, this.color});

  final double size;
  final Color? color;
  final _PaintFn paint;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FnPainter(resolved, paint)),
    );
  }
}

class _FnPainter extends CustomPainter {
  _FnPainter(this.color, this.paintFn);

  final Color color;
  final _PaintFn paintFn;

  @override
  void paint(Canvas canvas, Size size) => paintFn(canvas, size, color);

  @override
  bool shouldRepaint(covariant _FnPainter oldDelegate) =>
      oldDelegate.color != color;
}

Paint _stroke(Color color, {double width = 1.85}) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

void _paintSpeaker(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final body = Path()
    ..moveTo(s * 0.16, s * 0.38)
    ..lineTo(s * 0.34, s * 0.38)
    ..lineTo(s * 0.52, s * 0.22)
    ..lineTo(s * 0.52, s * 0.78)
    ..lineTo(s * 0.34, s * 0.62)
    ..lineTo(s * 0.16, s * 0.62)
    ..close();
  canvas.drawPath(body, p);
  canvas.drawArc(
    Rect.fromCircle(center: Offset(s * 0.58, s * 0.5), radius: s * 0.15),
    -math.pi / 3,
    2 * math.pi / 3,
    false,
    p,
  );
  canvas.drawArc(
    Rect.fromCircle(center: Offset(s * 0.58, s * 0.5), radius: s * 0.27),
    -math.pi / 3.1,
    2 * math.pi / 3.1,
    false,
    p,
  );
}

void _paintTv(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.14, s * 0.22, s * 0.72, s * 0.48),
      const Radius.circular(4),
    ),
    p,
  );
  canvas.drawLine(Offset(s * 0.34, s * 0.78), Offset(s * 0.66, s * 0.78), p);
  canvas.drawLine(Offset(s * 0.50, s * 0.70), Offset(s * 0.50, s * 0.78), p);
}

void _paintCheck(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color, width: 2.2);
  canvas.drawLine(Offset(s * 0.22, s * 0.52), Offset(s * 0.42, s * 0.72), p);
  canvas.drawLine(Offset(s * 0.42, s * 0.72), Offset(s * 0.78, s * 0.30), p);
}

void _paintTrash(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawLine(Offset(s * 0.22, s * 0.30), Offset(s * 0.78, s * 0.30), p);
  canvas.drawLine(Offset(s * 0.34, s * 0.22), Offset(s * 0.66, s * 0.22), p);
  canvas.drawLine(Offset(s * 0.38, s * 0.22), Offset(s * 0.38, s * 0.30), p);
  canvas.drawLine(Offset(s * 0.62, s * 0.22), Offset(s * 0.62, s * 0.30), p);
  final can = Path()
    ..moveTo(s * 0.28, s * 0.30)
    ..lineTo(s * 0.32, s * 0.80)
    ..lineTo(s * 0.68, s * 0.80)
    ..lineTo(s * 0.72, s * 0.30);
  canvas.drawPath(can, p);
  canvas.drawLine(Offset(s * 0.42, s * 0.40), Offset(s * 0.44, s * 0.70), p);
  canvas.drawLine(Offset(s * 0.58, s * 0.40), Offset(s * 0.56, s * 0.70), p);
}

void _paintRefresh(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color, width: 2.0);
  final c = Offset(s * 0.5, s * 0.5);
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: s * 0.30),
    -math.pi * 0.85,
    math.pi * 1.45,
    false,
    p,
  );
  final tip = Offset(
    c.dx + math.cos(-math.pi * 0.85) * s * 0.30,
    c.dy + math.sin(-math.pi * 0.85) * s * 0.30,
  );
  canvas.drawLine(tip, Offset(tip.dx - s * 0.12, tip.dy - s * 0.02), p);
  canvas.drawLine(tip, Offset(tip.dx - s * 0.02, tip.dy + s * 0.12), p);
}

void _paintMoon(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final outer = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(s * 0.48, s * 0.5), radius: s * 0.30),
    );
  final cut = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(s * 0.64, s * 0.40), radius: s * 0.24),
    );
  canvas.drawPath(
    Path.combine(PathOperation.difference, outer, cut),
    _fill(color),
  );
}

void _paintClock(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final c = Offset(s * 0.5, s * 0.5);
  final p = _stroke(color);
  canvas.drawCircle(c, s * 0.34, p);
  canvas.drawLine(c, Offset(s * 0.5, s * 0.32), p);
  canvas.drawLine(c, Offset(s * 0.68, s * 0.5), p);
}

void _paintCaretLeft(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color, width: 2.1);
  canvas.drawLine(Offset(s * 0.62, s * 0.22), Offset(s * 0.34, s * 0.5), p);
  canvas.drawLine(Offset(s * 0.34, s * 0.5), Offset(s * 0.62, s * 0.78), p);
}

void _paintCaretRight(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color, width: 2.1);
  canvas.drawLine(Offset(s * 0.38, s * 0.22), Offset(s * 0.66, s * 0.5), p);
  canvas.drawLine(Offset(s * 0.66, s * 0.5), Offset(s * 0.38, s * 0.78), p);
}

void _paintInfo(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.34, p);
  canvas.drawCircle(Offset(s * 0.5, s * 0.34), s * 0.035, _fill(color));
  canvas.drawLine(Offset(s * 0.5, s * 0.46), Offset(s * 0.5, s * 0.70), p);
}

void _paintBattery(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final r = RRect.fromRectAndRadius(
    Rect.fromLTWH(s * 0.14, s * 0.30, s * 0.62, s * 0.40),
    const Radius.circular(4),
  );
  canvas.drawRRect(r, p);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.78, s * 0.40, s * 0.08, s * 0.20),
      const Radius.circular(2),
    ),
    p,
  );
  canvas.drawLine(Offset(s * 0.42, s * 0.22), Offset(s * 0.42, s * 0.34), p);
  canvas.drawCircle(Offset(s * 0.42, s * 0.16), s * 0.035, _fill(color));
}

void _paintGear(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final c = Offset(s * 0.5, s * 0.5);
  final p = _stroke(color);
  canvas.drawCircle(c, s * 0.16, p);
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final i1 = Offset(
      c.dx + math.cos(a) * s * 0.22,
      c.dy + math.sin(a) * s * 0.22,
    );
    final o1 = Offset(
      c.dx + math.cos(a) * s * 0.36,
      c.dy + math.sin(a) * s * 0.36,
    );
    canvas.drawLine(i1, o1, p);
  }
  canvas.drawCircle(c, s * 0.36, p);
}

void _paintHouse(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final roof = Path()
    ..moveTo(s * 0.18, s * 0.48)
    ..lineTo(s * 0.5, s * 0.20)
    ..lineTo(s * 0.82, s * 0.48);
  canvas.drawPath(roof, p);
  final body = Path()
    ..moveTo(s * 0.26, s * 0.48)
    ..lineTo(s * 0.26, s * 0.80)
    ..lineTo(s * 0.74, s * 0.80)
    ..lineTo(s * 0.74, s * 0.48);
  canvas.drawPath(body, p);
  canvas.drawRect(Rect.fromLTWH(s * 0.44, s * 0.56, s * 0.12, s * 0.24), p);
}

void _paintDevices(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.14, s * 0.22, s * 0.40, s * 0.56),
      const Radius.circular(5),
    ),
    p,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.48, s * 0.34, s * 0.36, s * 0.44),
      const Radius.circular(4),
    ),
    p,
  );
}

void _paintPhone(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  // Handset proportions closer to a modern phone (not a tall oval).
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.5),
        width: s * 0.50,
        height: s * 0.72,
      ),
      Radius.circular(s * 0.11),
    ),
    p,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.24),
        width: s * 0.20,
        height: s * 0.045,
      ),
      Radius.circular(s * 0.02),
    ),
    p,
  );
  canvas.drawLine(Offset(s * 0.40, s * 0.78), Offset(s * 0.60, s * 0.78), p);
}

void _paintSpeakerSlash(Canvas canvas, Size size, Color color) {
  _paintSpeaker(canvas, size, color);
  final s = size.shortestSide;
  canvas.drawLine(
    Offset(s * 0.18, s * 0.18),
    Offset(s * 0.82, s * 0.82),
    _stroke(color, width: 2.0),
  );
}

void _paintWifiSlash(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final c = Offset(s * 0.5, s * 0.62);
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: s * 0.12),
    math.pi,
    math.pi,
    false,
    p,
  );
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: s * 0.24),
    math.pi * 1.1,
    math.pi * 0.8,
    false,
    p,
  );
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: s * 0.36),
    math.pi * 1.15,
    math.pi * 0.7,
    false,
    p,
  );
  canvas.drawLine(
    Offset(s * 0.2, s * 0.2),
    Offset(s * 0.8, s * 0.8),
    _stroke(color, width: 2),
  );
}

void _paintPlug(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawLine(Offset(s * 0.34, s * 0.18), Offset(s * 0.34, s * 0.38), p);
  canvas.drawLine(Offset(s * 0.66, s * 0.18), Offset(s * 0.66, s * 0.38), p);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.24, s * 0.38, s * 0.52, s * 0.28),
      const Radius.circular(4),
    ),
    p,
  );
  canvas.drawLine(Offset(s * 0.5, s * 0.66), Offset(s * 0.5, s * 0.84), p);
}

void _paintMusicMinus(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawCircle(Offset(s * 0.32, s * 0.68), s * 0.10, p);
  canvas.drawLine(Offset(s * 0.42, s * 0.68), Offset(s * 0.42, s * 0.24), p);
  canvas.drawLine(Offset(s * 0.42, s * 0.24), Offset(s * 0.72, s * 0.18), p);
  canvas.drawLine(Offset(s * 0.55, s * 0.72), Offset(s * 0.82, s * 0.72), p);
}

void _paintMoonStars(Canvas canvas, Size size, Color color) {
  _paintMoon(canvas, size, color);
  final s = size.shortestSide;
  canvas.drawCircle(Offset(s * 0.72, s * 0.28), s * 0.035, _fill(color));
  canvas.drawCircle(Offset(s * 0.82, s * 0.42), s * 0.025, _fill(color));
}

void _paintSun(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final c = Offset(s * 0.5, s * 0.5);
  final p = _stroke(color);
  canvas.drawCircle(c, s * 0.18, p);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    final inner = Offset(
      c.dx + math.cos(a) * s * 0.26,
      c.dy + math.sin(a) * s * 0.26,
    );
    final outer = Offset(
      c.dx + math.cos(a) * s * 0.38,
      c.dy + math.sin(a) * s * 0.38,
    );
    canvas.drawLine(inner, outer, p);
  }
}

void _paintSunrise(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final c = Offset(s * 0.5, s * 0.62);
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: s * 0.22),
    math.pi,
    -math.pi,
    false,
    p,
  );
  canvas.drawLine(Offset(s * 0.16, s * 0.62), Offset(s * 0.84, s * 0.62), p);
  for (final a in <double>[-math.pi * 0.75, -math.pi / 2, -math.pi * 0.25]) {
    final inner = Offset(
      c.dx + math.cos(a) * s * 0.28,
      c.dy + math.sin(a) * s * 0.28,
    );
    final outer = Offset(
      c.dx + math.cos(a) * s * 0.38,
      c.dy + math.sin(a) * s * 0.38,
    );
    canvas.drawLine(inner, outer, p);
  }
}

void _paintSunAfternoon(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final c = Offset(s * 0.42, s * 0.42);
  canvas.drawCircle(c, s * 0.16, p);
  for (final a in <double>[
    -math.pi * 0.7,
    -math.pi * 0.35,
    0,
    math.pi * 0.35,
  ]) {
    final inner = Offset(
      c.dx + math.cos(a) * s * 0.24,
      c.dy + math.sin(a) * s * 0.24,
    );
    final outer = Offset(
      c.dx + math.cos(a) * s * 0.36,
      c.dy + math.sin(a) * s * 0.36,
    );
    canvas.drawLine(inner, outer, p);
  }
  canvas.drawLine(Offset(s * 0.16, s * 0.74), Offset(s * 0.84, s * 0.74), p);
}

void _paintSunset(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final c = Offset(s * 0.5, s * 0.52);
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: s * 0.22),
    math.pi,
    -math.pi,
    false,
    p,
  );
  canvas.drawLine(Offset(s * 0.16, s * 0.52), Offset(s * 0.84, s * 0.52), p);
}

void _paintProhibit(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.34, p);
  canvas.drawLine(Offset(s * 0.28, s * 0.28), Offset(s * 0.72, s * 0.72), p);
}

void _paintCoffee(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  // Cup body
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.22, s * 0.36, s * 0.48, s * 0.40),
      const Radius.circular(4),
    ),
    p,
  );
  // Handle
  canvas.drawArc(
    Rect.fromLTWH(s * 0.62, s * 0.42, s * 0.22, s * 0.24),
    -math.pi / 2.2,
    math.pi,
    false,
    p,
  );
  // Saucer
  canvas.drawLine(Offset(s * 0.18, s * 0.80), Offset(s * 0.74, s * 0.80), p);
  // Steam
  final steam = _stroke(color, width: 1.5);
  canvas.drawArc(
    Rect.fromLTWH(s * 0.32, s * 0.14, s * 0.12, s * 0.18),
    math.pi * 0.15,
    math.pi * 0.7,
    false,
    steam,
  );
  canvas.drawArc(
    Rect.fromLTWH(s * 0.48, s * 0.12, s * 0.12, s * 0.18),
    math.pi * 0.15,
    math.pi * 0.7,
    false,
    steam,
  );
}

void _paintLogLines(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.20, s * 0.16, s * 0.60, s * 0.68),
      const Radius.circular(3),
    ),
    p,
  );
  canvas.drawLine(Offset(s * 0.32, s * 0.36), Offset(s * 0.68, s * 0.36), p);
  canvas.drawLine(Offset(s * 0.32, s * 0.50), Offset(s * 0.68, s * 0.50), p);
  canvas.drawLine(Offset(s * 0.32, s * 0.64), Offset(s * 0.56, s * 0.64), p);
}

void _paintBars(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color, width: 2.0);
  canvas.drawLine(Offset(s * 0.30, s * 0.70), Offset(s * 0.30, s * 0.42), p);
  canvas.drawLine(Offset(s * 0.50, s * 0.70), Offset(s * 0.50, s * 0.22), p);
  canvas.drawLine(Offset(s * 0.70, s * 0.70), Offset(s * 0.70, s * 0.52), p);
}

void _paintTrendUp(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color, width: 2.0);
  canvas.drawLine(Offset(s * 0.18, s * 0.70), Offset(s * 0.42, s * 0.48), p);
  canvas.drawLine(Offset(s * 0.42, s * 0.48), Offset(s * 0.52, s * 0.58), p);
  canvas.drawLine(Offset(s * 0.52, s * 0.58), Offset(s * 0.78, s * 0.26), p);
  canvas.drawLine(Offset(s * 0.78, s * 0.26), Offset(s * 0.58, s * 0.26), p);
  canvas.drawLine(Offset(s * 0.78, s * 0.26), Offset(s * 0.78, s * 0.46), p);
}

void _paintAlertCircle(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.34, p);
  canvas.drawLine(Offset(s * 0.5, s * 0.32), Offset(s * 0.5, s * 0.54), p);
  canvas.drawCircle(Offset(s * 0.5, s * 0.66), s * 0.04, _fill(color));
}

void _paintFlame(Canvas canvas, Size size, Color color) {
  final s = size.shortestSide;
  final p = _stroke(color);
  final outer = Path()
    ..moveTo(s * 0.50, s * 0.16)
    ..cubicTo(s * 0.34, s * 0.38, s * 0.26, s * 0.50, s * 0.28, s * 0.66)
    ..cubicTo(s * 0.30, s * 0.84, s * 0.40, s * 0.88, s * 0.50, s * 0.88)
    ..cubicTo(s * 0.60, s * 0.88, s * 0.70, s * 0.84, s * 0.72, s * 0.66)
    ..cubicTo(s * 0.74, s * 0.50, s * 0.66, s * 0.38, s * 0.50, s * 0.16);
  canvas.drawPath(outer, p);
  final inner = Path()
    ..moveTo(s * 0.50, s * 0.46)
    ..cubicTo(s * 0.42, s * 0.58, s * 0.42, s * 0.66, s * 0.50, s * 0.76)
    ..cubicTo(s * 0.58, s * 0.66, s * 0.58, s * 0.58, s * 0.50, s * 0.46);
  canvas.drawPath(inner, p);
}

double _u(Size size) => size.shortestSide / 32;

void _svg(Canvas canvas, Size size, String d, Paint paint) {
  canvas.drawPath(_svgPath(d, size.shortestSide), paint);
}

void _disc(
  Canvas canvas,
  Size size,
  double cx,
  double cy,
  double r,
  Paint paint,
) {
  final k = _u(size);
  canvas.drawCircle(Offset(cx * k, cy * k), r * k, paint);
}

void _roundRect(
  Canvas canvas,
  Size size,
  double x,
  double y,
  double w,
  double h,
  double rx,
  Paint paint,
) {
  final k = _u(size);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(x * k, y * k, w * k, h * k),
      Radius.circular(rx * k),
    ),
    paint,
  );
}

Paint _sw(Color color, Size size, double width) =>
    _stroke(color, width: width * _u(size));

void _paintPrayerTimes(Canvas canvas, Size size, Color color) {
  _svg(
    canvas,
    size,
    'M7 28V14.5C7 9.3 11 5.5 16 4c5 1.5 9 5.3 9 10.5V28z',
    _fill(PrayerCastColors.leaf.withValues(alpha: 0.16)),
  );
  _svg(
    canvas,
    size,
    'M7 28V14.5C7 9.3 11 5.5 16 4c5 1.5 9 5.3 9 10.5V28M4.5 28h23',
    _sw(color, size, 1.7),
  );
  _disc(canvas, size, 16, 17.5, 5, _sw(color, size, 1.6));
  _svg(canvas, size, 'M16 14.8v2.9l1.9 1.2', _sw(color, size, 1.6));
}

void _paintPrayerTracker(Canvas canvas, Size size, Color color) {
  _roundRect(
    canvas,
    size,
    7,
    4,
    18,
    24,
    2.5,
    _fill(PrayerCastColors.leaf.withValues(alpha: 0.16)),
  );
  _roundRect(canvas, size, 7, 4, 18, 24, 2.5, _sw(color, size, 1.7));
  _svg(
    canvas,
    size,
    'M11 13.5c0-2.6 2.2-4.7 5-5.5 2.8.8 5 2.9 5 5.5V20H11z',
    _sw(color, size, 1.5),
  );
  _svg(
    canvas,
    size,
    'M9.5 24h13M9.5 24.2v2M12.5 24.2v2M15.5 24.2v2M18.5 24.2v2M21.5 24.2v2',
    _sw(color, size, 1.2),
  );
  _svg(canvas, size, 'M13.2 15.3l2 2 3.8-3.9', _sw(color, size, 1.7));
}

void _paintQibla(Canvas canvas, Size size, Color color) {
  _disc(
    canvas,
    size,
    16,
    16,
    12,
    _fill(PrayerCastColors.leaf.withValues(alpha: 0.16)),
  );
  _disc(canvas, size, 16, 16, 12, _sw(color, size, 1.7));
  _svg(
    canvas,
    size,
    'M16 5.6v1.8M16 24.6v1.8M5.6 16h1.8M24.6 16h1.8',
    _sw(color, size, 1.4),
  );
  _svg(canvas, size, 'M19.6 12.4l-2.2 5-5 2.2 2.2-5z', _sw(color, size, 1.6));
  _roundRect(canvas, size, 19.4, 8.4, 4.2, 4.2, 0.6, _fill(color));
  _svg(canvas, size, 'M19.4 9.6h4.2', _sw(PrayerCastColors.dawn, size, 0.9));
}

void _paintMorningAdhkar(Canvas canvas, Size size, Color color) {
  _svg(
    canvas,
    size,
    'M8.5 22a7.5 7.5 0 0115 0z',
    _fill(PrayerCastColors.dawn.withValues(alpha: 0.22)),
  );
  _svg(
    canvas,
    size,
    'M8.5 22a7.5 7.5 0 0115 0M4 22h24M8 26h16',
    _sw(color, size, 1.7),
  );
  _svg(
    canvas,
    size,
    'M16 6.5v3M7 10.5l2 2M25 10.5l-2 2M3.5 17h2.5M26 17h2.5',
    _sw(color, size, 1.6),
  );
}

void _paintEveningAdhkar(Canvas canvas, Size size, Color color) {
  const crescent = 'M20.5 5.5A10.5 10.5 0 1026.5 23 8.5 8.5 0 0120.5 5.5z';
  _svg(
    canvas,
    size,
    crescent,
    _fill(PrayerCastColors.leaf.withValues(alpha: 0.16)),
  );
  _svg(canvas, size, crescent, _sw(color, size, 1.7));
  _svg(
    canvas,
    size,
    'M24 9.5l.7 1.6 1.6.7-1.6.7-.7 1.6-.7-1.6-1.6-.7 1.6-.7z',
    _fill(PrayerCastColors.dawn),
  );
  _svg(
    canvas,
    size,
    'M27.5 15.5l.4.9.9.4-.9.4-.4.9-.4-.9-.9-.4.9-.4z',
    _fill(PrayerCastColors.dawn),
  );
}

void _paintTasbih(Canvas canvas, Size size, Color color) {
  final bead = _fill(PrayerCastColors.leaf.withValues(alpha: 0.35));
  final beadStroke = _sw(color, size, 1.3);
  _disc(canvas, size, 16, 13, 8.5, _sw(color.withValues(alpha: 0.5), size, 1));
  for (final center in const [
    (16.0, 4.5),
    (22.0, 7.0),
    (24.5, 13.0),
    (22.0, 19.0),
    (10.0, 19.0),
    (7.5, 13.0),
    (10.0, 7.0),
  ]) {
    _disc(canvas, size, center.$1, center.$2, 2, bead);
    _disc(canvas, size, center.$1, center.$2, 2, beadStroke);
  }
  _svg(canvas, size, 'M16 21.5v2.5', _sw(color, size, 1.5));
  _disc(canvas, size, 16, 21.5, 2.2, _fill(PrayerCastColors.dawn));
  _disc(canvas, size, 16, 21.5, 2.2, beadStroke);
  _svg(
    canvas,
    size,
    'M14.3 25l-1 3.5M16 25v3.8M17.7 25l1 3.5',
    _sw(PrayerCastColors.dawn, size, 1.4),
  );
}

final _svgToken = RegExp(
  r'[MmLlHhVvCcAaZz]|[+-]?(?:\d*\.\d+|\d+)(?:[eE][+-]?\d+)?',
);

bool _svgCommand(String token) =>
    token.length == 1 && RegExp(r'[A-Za-z]').hasMatch(token);

Path _svgPath(String d, double s) {
  final k = s / 32;
  final tokens = _svgToken.allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  String? cmd;
  var cx = 0.0;
  var cy = 0.0;
  var sx = 0.0;
  var sy = 0.0;

  double number() => double.parse(tokens[i++]);

  int flag() {
    final raw = tokens[i];
    if (raw == '0' || raw == '1') {
      i++;
      return raw == '1' ? 1 : 0;
    }
    if (raw.startsWith('0') || raw.startsWith('1')) {
      final bit = raw.startsWith('1') ? 1 : 0;
      final rest = raw.substring(1);
      if (rest.isEmpty) {
        i++;
      } else {
        tokens[i] = rest;
      }
      return bit;
    }
    throw FormatException('SVG arc flag "$raw"');
  }

  while (i < tokens.length) {
    if (_svgCommand(tokens[i])) {
      cmd = tokens[i++];
    } else if (cmd == null) {
      throw FormatException('SVG path expected a command');
    }
    switch (cmd) {
      case 'M':
        cx = number();
        cy = number();
        path.moveTo(cx * k, cy * k);
        sx = cx;
        sy = cy;
        cmd = 'L';
      case 'm':
        cx += number();
        cy += number();
        path.moveTo(cx * k, cy * k);
        sx = cx;
        sy = cy;
        cmd = 'l';
      case 'L':
        cx = number();
        cy = number();
        path.lineTo(cx * k, cy * k);
      case 'l':
        cx += number();
        cy += number();
        path.lineTo(cx * k, cy * k);
      case 'H':
        cx = number();
        path.lineTo(cx * k, cy * k);
      case 'h':
        cx += number();
        path.lineTo(cx * k, cy * k);
      case 'V':
        cy = number();
        path.lineTo(cx * k, cy * k);
      case 'v':
        cy += number();
        path.lineTo(cx * k, cy * k);
      case 'C':
        final x1 = number();
        final y1 = number();
        final x2 = number();
        final y2 = number();
        final x = number();
        final y = number();
        path.cubicTo(x1 * k, y1 * k, x2 * k, y2 * k, x * k, y * k);
        cx = x;
        cy = y;
      case 'c':
        final x1 = cx + number();
        final y1 = cy + number();
        final x2 = cx + number();
        final y2 = cy + number();
        final x = cx + number();
        final y = cy + number();
        path.cubicTo(x1 * k, y1 * k, x2 * k, y2 * k, x * k, y * k);
        cx = x;
        cy = y;
      case 'A':
      case 'a':
        final rx = number().abs();
        final ry = number().abs();
        final rotation = number() * math.pi / 180;
        final large = flag() == 1;
        final sweep = flag() == 1;
        var x = number();
        var y = number();
        if (cmd == 'a') {
          x += cx;
          y += cy;
        }
        path.arcToPoint(
          Offset(x * k, y * k),
          radius: Radius.elliptical(rx * k, ry * k),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
        cx = x;
        cy = y;
      case 'Z':
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
        cmd = null;
      default:
        throw FormatException('SVG command $cmd');
    }
  }
  return path;
}
