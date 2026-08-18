import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  for (final a in <double>[-math.pi * 0.7, -math.pi * 0.35, 0, math.pi * 0.35]) {
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
