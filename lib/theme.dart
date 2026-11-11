import 'package:flutter/material.dart';

/// Kolory z makiet.
class AppColors {
  static const ink = Color(0xFF14171C);
  static const background = Color(0xFFF4F5F8);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFF5B6270);
  static const border = Color(0xFFE1E4EA);
  static const passwords = Color(0xFF2457D6);
  static const passwordsSoft = Color(0xFFE6EDFC);
  static const payments = Color(0xFFB45309);
  static const paymentsSoft = Color(0xFFFCEBDD);
  static const danger = Color(0xFFB42318);

  /// Kolory „awatarów” z pierwszą literą nazwy.
  static const avatars = [
    Color(0xFFC2410C),
    Color(0xFF0F766E),
    Color(0xFF2457D6),
    Color(0xFFB42318),
    Color(0xFF7A1F1F),
    Color(0xFF334155),
    Color(0xFF6D28D9),
    Color(0xFF1F4AB8),
  ];

  static Color avatarFor(String name) {
    final key = name.trim().toLowerCase();
    var hash = 0;
    for (final c in key.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return avatars[hash % avatars.length];
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.passwords,
    surface: AppColors.surface,
  ).copyWith(primary: AppColors.passwords, error: AppColors.danger, onSurface: AppColors.ink);
  final radius = BorderRadius.circular(14);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.passwords, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.passwords,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Odmiana motywu dla części „Opłaty” (pomarańczowy akcent zamiast niebieskiego).
ThemeData paymentsTheme(ThemeData base) {
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(primary: AppColors.payments),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(backgroundColor: AppColors.payments),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.payments, width: 2),
      ),
    ),
  );
}
