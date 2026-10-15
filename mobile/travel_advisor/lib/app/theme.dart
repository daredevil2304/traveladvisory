import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors: Executive Obsidian Navy, Royal Cobalt, and Warm Champagne Amber
  static const Color forestGreen = Color(0xFF1E3A8A); // Deep Royal Sapphire
  static const Color deepGreen = Color(0xFF0F172A); // Executive Obsidian Navy
  static const Color royalCobalt = Color(0xFF2563EB); // Vibrant Expressway Blue
  static const Color teal = Color(0xFF0D9488); // Precision Emerald Teal
  static const Color amberGold = Color(0xFFD97706); // Warm Champagne Amber Accent
  static const Color amberGoldLight = Color(0xFFFEF3C7); // Champagne Glow
  static const Color mint = Color(0xFFEFF6FF); // Soft Ice-Blue Card Tint
  static const Color lightMint = Color(0xFFF8FAFC); // Clean Slate Canvas

  static const Color orange = Color(0xFFD97706);

  static const Color darkNavy = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color primary = forestGreen;
  static const Color secondary = royalCobalt;
  static const Color accent = amberGold;
  static const Color textPrimary = darkNavy;
  static const Color white = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color danger = Color(0xFFEF4444);
  static const Color crimsonRed = Color(0xFFEF4444);
  static const Color alertAmber = Color(0xFFD97706);
  static const Color emeraldGreen = Color(0xFF059669);
  static const Color subtleGrey = Color(0xFF94A3B8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      scaffoldBackgroundColor: lightMint,

      colorScheme: ColorScheme.fromSeed(
        seedColor: forestGreen,
        brightness: Brightness.light,
      ).copyWith(
        primary: forestGreen,
        secondary: teal,
        surface: white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: lightMint,
        foregroundColor: darkNavy,
        elevation: 0,
        centerTitle: false,
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: darkNavy,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: darkNavy,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkNavy,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkNavy,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textSecondary,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.4,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),

        hintStyle: const TextStyle(
          color: Color(0xFF8A99A3),
          fontSize: 15,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: border,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: forestGreen,
            width: 1.5,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forestGreen,
          foregroundColor: white,

          minimumSize: const Size(
            double.infinity,
            56,
          ),

          elevation: 0,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}