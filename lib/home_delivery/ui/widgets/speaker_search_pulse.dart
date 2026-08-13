import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons/premium_icons.dart';
import '../theme/prayer_cast_colors.dart';

/// Soft radiating rings around a speaker icon — “searching”, not a Material spinner.
///
/// Loop is ~1.2s so repeat visits stay calm.
class SpeakerSearchPulse extends StatefulWidget {
  const SpeakerSearchPulse({
    super.key,
    this.size = 96,
  });

  final double size;

  @override
  State<SpeakerSearchPulse> createState() => _SpeakerSearchPulseState();
}

class _SpeakerSearchPulseState extends State<SpeakerSearchPulse>
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
    final size = widget.size;
    return Semantics(
      label: 'Searching for speakers',
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _PulseRingsPainter(progress: _controller.value),
              child: Center(
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    color: PrayerCastColors.canopy,
                    borderRadius: BorderRadius.circular(size * 0.14),
                  ),
                  alignment: Alignment.center,
                  child: PremiumIcons.speaker(
                    size: size * 0.22,
                    color: PrayerCastColors.mist,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PulseRingsPainter extends CustomPainter {
  _PulseRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2;

    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = maxR * (0.28 + 0.72 * t);
      final opacity = (1.0 - t) * 0.45;
      final paint = Paint()
        ..color = PrayerCastColors.mist.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
