import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brand = Color(0xFF198754);
  static const brandDark = Color(0xFF0F6B3D);
  static const brandSoft = Color(0xFFEBF5E9);
  static const accent = Color(0xFFFFC107);
  static const ink = Color(0xFF17221A);
  static const muted = Color(0xFF6C757D);
  static const border = Color(0xFFE5E9E4);
  static const canvas = Color(0xFFF7F8F6);

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: brand,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: ink,
          surface: Colors.white,
          onSurface: ink,
          outline: border,
          error: const Color(0xFFC0392B),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      dividerColor: border,
      extensions: [
        ClerkThemeExtension(
          colors: const ClerkThemeColors(
            background: Colors.white,
            altBackground: canvas,
            borderSide: border,
            text: ink,
            icon: muted,
            lightweightText: muted,
            error: Color(0xFFC0392B),
            accent: brand,
          ),
        ),
      ],
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: brandSoft,
        elevation: 3,
        height: 72,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brand, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandDark,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: brandSoft,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          color: ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
