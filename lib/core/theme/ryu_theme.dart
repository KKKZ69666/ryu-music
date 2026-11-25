import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ryu_colors.dart';

class RyuTheme {
  RyuTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: RyuColors.violet,
      brightness: Brightness.dark,
    ).copyWith(
      surface: RyuColors.charcoal,
      primary: RyuColors.violet,
      secondary: RyuColors.indigo,
      tertiary: RyuColors.blue,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: RyuColors.void_,
    );

    return base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor: RyuColors.textPrimary,
        displayColor: RyuColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: RyuColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
