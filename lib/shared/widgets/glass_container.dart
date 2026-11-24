import 'dart:ui';
import 'package:flutter/material.dart';

/// Liquid-glass surface: blur + translucent fill + reflective border.
/// Use sparingly (nav bar, mini-player, overlays); blur is GPU-costly.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.blur = 24,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
