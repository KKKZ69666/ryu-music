import 'package:flutter/material.dart';

/// RYU palette: deep black base, violet/indigo/blue accents.
class RyuColors {
  RyuColors._();

  static const Color void_ = Color(0xFF07070B);
  static const Color charcoal = Color(0xFF0F0F16);
  static const Color surface = Color(0xFF16161F);
  static const Color surfaceHigh = Color(0xFF1F1F2B);

  static const Color violet = Color(0xFF8B5CF6);
  static const Color indigo = Color(0xFF6366F1);
  static const Color blue = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFFF4F4F8);
  static const Color textSecondary = Color(0xFF9A9AB0);

  static const LinearGradient accent = LinearGradient(
    colors: [violet, indigo, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
