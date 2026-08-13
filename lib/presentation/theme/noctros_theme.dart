import 'package:flutter/material.dart';

/// Nocturnal communication palette: deep navy atmosphere with aqua signal.
class NoctrosTheme {
  static const Color _ink = Color(0xFF0B1420);
  static const Color _mist = Color(0xFFF3F6F8);
  static const Color _signal = Color(0xFF1F8A78);
  static const Color _signalSoft = Color(0xFF2EB39A);

  static const String _bodyFont = 'Manrope';
  static const String _displayFont = 'Fraunces';

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _signal,
      brightness: Brightness.light,
      primary: _signal,
      surface: Colors.white,
    );

    final textTheme = _textTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _mist,
      fontFamily: _bodyFont,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _mist.withValues(alpha: 0.92),
        foregroundColor: _ink,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        indicatorColor: _signal.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _signal,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: _ink.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _signalSoft,
      brightness: Brightness.dark,
      primary: _signalSoft,
      surface: const Color(0xFF121A24),
    );

    final textTheme = _textTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _ink,
      fontFamily: _bodyFont,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _ink.withValues(alpha: 0.92),
        foregroundColor: Colors.white,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF101821).withValues(alpha: 0.96),
        indicatorColor: _signalSoft.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _signalSoft,
        foregroundColor: Color(0xFF062018),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF172130),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: _displayFont,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.1,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: _displayFont,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.15,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: _displayFont,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: _bodyFont,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: _bodyFont,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: _bodyFont,
        height: 1.35,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: _bodyFont,
        height: 1.35,
      ),
      labelLarge: base.labelLarge?.copyWith(fontFamily: _bodyFont),
      labelMedium: base.labelMedium?.copyWith(fontFamily: _bodyFont),
    );
  }
}
