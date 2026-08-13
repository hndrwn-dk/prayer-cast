import 'package:flutter/material.dart';

import 'prayer_cast_colors.dart';

/// Soft mist gradient + subtle radial wash — atmosphere without flat fill.
class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PrayerCastColors.atmosphere,
                PrayerCastColors.surface,
                Color(0xFFDCE8E1),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        const Positioned(
          top: -80,
          right: -40,
          child: _GlowBlob(
            diameter: 280,
            color: Color(0x552F8F6B),
          ),
        ),
        const Positioned(
          bottom: -60,
          left: -50,
          child: _GlowBlob(
            diameter: 240,
            color: Color(0x44C9852A),
          ),
        ),
        const CustomPaint(painter: _SoftGridPainter()),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Very light diagonal hatch — texture without noise chrome.
class _SoftGridPainter extends CustomPainter {
  const _SoftGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PrayerCastColors.mistDeep.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gentle entrance for hero content.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.04),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (!mounted) return;
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Soft pulse on the brand mark — presence, not decoration spam.
class BreathPulse extends StatefulWidget {
  const BreathPulse({super.key, required this.child});

  final Widget child;

  @override
  State<BreathPulse> createState() => _BreathPulseState();
}

class _BreathPulseState extends State<BreathPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1 + (0.03 * t);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}
