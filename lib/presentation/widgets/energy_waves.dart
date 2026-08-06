import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/assistant_ui_provider.dart';
import '../theme/noctros_theme.dart';

/// Soft horizontal energy ribbons flanking the AI orb.
class EnergyWaves extends StatefulWidget {
  const EnergyWaves({
    super.key,
    required this.state,
    this.height = 180,
  });

  final AssistantVisualState state;
  final double height;

  @override
  State<EnergyWaves> createState() => _EnergyWavesState();
}

class _EnergyWavesState extends State<EnergyWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant EnergyWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fast = widget.state == AssistantVisualState.listening ||
        widget.state == AssistantVisualState.speaking;
    _controller.duration = Duration(milliseconds: fast ? 2200 : 4800);
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amplify = switch (widget.state) {
      AssistantVisualState.idle => 0.55,
      AssistantVisualState.listening => 1.0,
      AssistantVisualState.thinking => 0.75,
      AssistantVisualState.speaking => 1.1,
    };

    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _WavesPainter(
                progress: _controller.value,
                amplify: amplify,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter({required this.progress, required this.amplify});

  final double progress;
  final double amplify;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    for (var layer = 0; layer < 3; layer++) {
      final path = Path();
      final amp = (10.0 + layer * 8) * amplify;
      final phase = progress * math.pi * 2 + layer * 0.9;
      path.moveTo(0, midY);
      for (var x = 0.0; x <= size.width; x += 6) {
        final y = midY +
            math.sin((x / size.width * math.pi * 2) + phase) * amp +
            math.sin((x / 40) + phase * 1.4) * (amp * 0.35);
        path.lineTo(x, y);
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 - (layer * 0.4)
        ..color = [
          NoctrosTheme.accentSoft.withValues(alpha: 0.55),
          NoctrosTheme.accent.withValues(alpha: 0.4),
          NoctrosTheme.glow.withValues(alpha: 0.28),
        ][layer]
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.amplify != amplify;
  }
}
