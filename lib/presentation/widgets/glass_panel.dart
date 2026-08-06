import 'dart:ui';

import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 28,
    this.opacity = 0.08,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: (isDark ? Colors.white : Colors.white)
                .withValues(alpha: isDark ? opacity : 0.72),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class PremiumBackground extends StatelessWidget {
  const PremiumBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF070A12),
                  Color(0xFF10182B),
                  Color(0xFF0A1020),
                ]
              : const [
                  Color(0xFFF7F8FC),
                  Color(0xFFE8EEFF),
                  Color(0xFFF4F6FB),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _GlowBlob(
              color: const Color(0xFF6EA8FF).withValues(alpha: 0.28),
              size: 220,
            ),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _GlowBlob(
              color: const Color(0xFF9B7BFF).withValues(alpha: 0.22),
              size: 260,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 90, spreadRadius: size * 0.35),
          ],
        ),
      ),
    );
  }
}
