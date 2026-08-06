import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/assistant_ui_provider.dart';
import '../theme/noctros_theme.dart';

/// Animated Noctros presence orb — idle / listening / thinking / speaking.
class AiOrb extends StatefulWidget {
  const AiOrb({
    super.key,
    required this.state,
    this.size = 220,
  });

  final AssistantVisualState state;
  final double size;

  @override
  State<AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<AiOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;
  late final AnimationController _speak;
  late final AnimationController _particles;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _speak = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _particles = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _sync();
    }
  }

  void _sync() {
    switch (widget.state) {
      case AssistantVisualState.idle:
        _pulse
          ..duration = const Duration(milliseconds: 2400)
          ..repeat(reverse: true);
        _spin.stop();
        _speak.stop();
      case AssistantVisualState.listening:
        _pulse
          ..duration = const Duration(milliseconds: 900)
          ..repeat(reverse: true);
        _spin.stop();
        _speak.stop();
      case AssistantVisualState.thinking:
        _pulse
          ..duration = const Duration(milliseconds: 1400)
          ..repeat(reverse: true);
        _spin.repeat();
        _speak.stop();
      case AssistantVisualState.speaking:
        _pulse
          ..duration = const Duration(milliseconds: 700)
          ..repeat(reverse: true);
        _spin.stop();
        _speak.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _speak.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _spin, _speak, _particles]),
        builder: (context, _) {
          final pulse = 0.92 + (_pulse.value * 0.1);
          final speakBoost = widget.state == AssistantVisualState.speaking
              ? 1 + (_speak.value * 0.08)
              : 1.0;
          return CustomPaint(
            painter: _OrbPainter(
              progress: _particles.value,
              spin: _spin.value,
              intensity: pulse * speakBoost,
              state: widget.state,
            ),
            child: Center(
              child: Transform.scale(
                scale: pulse * speakBoost,
                child: Container(
                  width: size * 0.52,
                  height: size * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFE8F4FF),
                        NoctrosTheme.glow,
                        NoctrosTheme.accent,
                        NoctrosTheme.accentSoft,
                      ],
                      stops: [0.0, 0.35, 0.7, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NoctrosTheme.glow.withValues(alpha: 0.45),
                        blurRadius: 36 * pulse,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: NoctrosTheme.accentSoft.withValues(alpha: 0.35),
                        blurRadius: 60 * pulse,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.progress,
    required this.spin,
    required this.intensity,
    required this.state,
  });

  final double progress;
  final double spin;
  final double intensity;
  final AssistantVisualState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38 * intensity;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = state == AssistantVisualState.thinking ? 2.4 : 1.4
      ..color = NoctrosTheme.accent.withValues(alpha: 0.35);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin * math.pi * 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, radius * 1.15, ring);
    canvas.drawCircle(center, radius * 1.32, ring);
    canvas.restore();

    final particlePaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 14; i++) {
      final angle = (progress * math.pi * 2) + (i * (math.pi * 2 / 14));
      final dist = radius * (1.2 + (i.isEven ? 0.18 : 0.08));
      final offset = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      canvas.drawCircle(offset, i.isEven ? 2.2 : 1.4, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.spin != spin ||
        oldDelegate.intensity != intensity ||
        oldDelegate.state != state;
  }
}
