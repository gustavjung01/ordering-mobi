import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const brand = Color(0xFF0B356D);
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      extensions: [
        ClerkThemeExtension(
          colors: const ClerkThemeColors(
            background: Colors.white,
            altBackground: Color(0xFFF6F7F9),
            borderSide: Color(0xFFDDE3EC),
            text: Color(0xFF172033),
            icon: Color(0xFF64748B),
            lightweightText: Color(0xFF64748B),
            error: Color(0xFFB3261E),
            accent: brand,
          ),
        ),
      ],
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF172033),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
  }
}
