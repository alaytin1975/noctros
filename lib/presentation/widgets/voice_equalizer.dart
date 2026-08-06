import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/assistant_ui_provider.dart';
import '../theme/noctros_theme.dart';

/// Bottom waveform visualizer — reactive for listening/speaking, calm when idle.
class VoiceEqualizer extends StatefulWidget {
  const VoiceEqualizer({
    super.key,
    required this.state,
    this.barCount = 36,
    this.height = 56,
  });

  final AssistantVisualState state;
  final int barCount;
  final double height;

  @override
  State<VoiceEqualizer> createState() => _VoiceEqualizerState();
}

class _VoiceEqualizerState extends State<VoiceEqualizer>
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
    final active = widget.state == AssistantVisualState.listening ||
        widget.state == AssistantVisualState.speaking;
    final thinking = widget.state == AssistantVisualState.thinking;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _EqualizerPainter(
              progress: _controller.value,
              intensity: active ? 1.0 : (thinking ? 0.35 : 0.18),
              speaking: widget.state == AssistantVisualState.speaking,
            ),
          );
        },
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({
    required this.progress,
    required this.intensity,
    required this.speaking,
  });

  final double progress;
  final double intensity;
  final bool speaking;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 40;
    final barWidth = size.width / (bars * 1.7);
    final gap = barWidth * 0.7;
    final midY = size.height / 2;

    for (var i = 0; i < bars; i++) {
      final t = i / bars;
      final wave = math.sin((progress * math.pi * 2) + (i * 0.45));
      final envelope = math.sin(t * math.pi);
      final speakBoost = speaking ? 0.35 : 0.0;
      final h = (6 +
              (size.height * 0.42 * intensity * envelope * (0.55 + 0.45 * wave)) +
              (size.height * speakBoost * envelope))
          .clamp(3.0, size.height);

      final x = i * (barWidth + gap) + gap;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, midY),
          width: barWidth,
          height: h,
        ),
        const Radius.circular(99),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            NoctrosTheme.accentSoft.withValues(alpha: 0.85),
            NoctrosTheme.glow,
            Colors.white.withValues(alpha: 0.95),
          ],
        ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.speaking != speaking;
  }
}
