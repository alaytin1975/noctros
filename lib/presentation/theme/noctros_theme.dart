import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Noctros visual system — dark-first glassmorphism Material 3.
class NoctrosTheme {
  static const voidColor = Color(0xFF070A12);
  static const surface = Color(0xFF101522);
  static const glass = Color(0x1AFFFFFF);
  static const accent = Color(0xFF6EA8FF);
  static const accentSoft = Color(0xFF9B7BFF);
  static const glow = Color(0xFF4DE1FF);

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark ? Colors.white : const Color(0xFF0E1320);
    final muted = brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF5C6578);
    return TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        color: base,
        letterSpacing: -1.2,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        color: base,
        letterSpacing: -0.6,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w600,
        color: base,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w600,
        color: base,
      ),
      bodyLarge: GoogleFonts.manrope(color: base, height: 1.45),
      bodyMedium: GoogleFonts.manrope(color: muted, height: 1.45),
      bodySmall: GoogleFonts.manrope(color: muted, fontSize: 12),
      labelLarge: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: base),
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF2F6BFF),
      secondary: accentSoft,
      surface: const Color(0xFFF4F6FB),
    );
    return _base(scheme, Brightness.light, const Color(0xFFF2F4FA));
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      secondary: accentSoft,
      surface: surface,
      onSurface: Colors.white,
    );
    return _base(scheme, Brightness.dark, voidColor);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Brightness brightness,
    Color scaffold,
  ) {
    final text = _textTheme(brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: Colors.white.withValues(
              alpha: brightness == Brightness.dark ? 0.08 : 0.4,
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        hintStyle: text.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xEE0C101A)
            : Colors.white.withValues(alpha: 0.92),
        indicatorColor: accent.withValues(alpha: 0.22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            brightness == Brightness.dark ? const Color(0xFF151A28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
