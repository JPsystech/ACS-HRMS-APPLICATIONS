import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/acs_theme_ext.dart';

class BirthdayThemeWrapper extends StatefulWidget {
  const BirthdayThemeWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<BirthdayThemeWrapper> createState() => _BirthdayThemeWrapperState();
}

class _BirthdayThemeWrapperState extends State<BirthdayThemeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  static const int _kParticleCount = 40;
  static const Duration _kCycle = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kCycle)..repeat();
    _particles = List.generate(_kParticleCount, (i) => _Particle.random());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerGradient = theme.acs.gradientSoftBackground;

    return Stack(
      children: [
        // Soft gradient header background (subtle).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: headerGradient),
            ),
          ),
        ),
        // Lightweight confetti overlay; repaints via controller only when wrapped.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    t: _ctrl.value,
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    alt: theme.colorScheme.secondary.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Existing content.
        widget.child,
      ],
    );
  }
}

class _Particle {
  final double x0;
  final double y0;
  final double speed;
  final double size;
  final double phase;

  _Particle(this.x0, this.y0, this.speed, this.size, this.phase);

  factory _Particle.random() {
    final r = math.Random();
    return _Particle(
      r.nextDouble(),               // x0 (0..1) relative
      r.nextDouble(),               // y0 (0..1) relative
      0.15 + r.nextDouble() * 0.35, // speed
      2.0 + r.nextDouble() * 3.0,   // size
      r.nextDouble() * math.pi * 2, // phase
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1
  final Color color;
  final Color alt;

  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.color,
    required this.alt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      // Drift down, loop at bottom; small horizontal sway.
      final y = (p.y0 + (t * p.speed)) % 1.0;
      final sway = math.sin((t * math.pi * 2) + p.phase) * 0.02;
      final x = (p.x0 + sway) % 1.0;
      paint.color = (i.isEven ? color : alt);
      canvas.drawCircle(Offset(x * size.width, y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.particles != particles;
}
