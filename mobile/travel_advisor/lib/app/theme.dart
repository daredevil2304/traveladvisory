import 'package:flutter/material.dart';

class AppTheme {
  // Executive Multi-Tone Blues & Accents
  static const Color midnightNavy = Color(0xFF0A1128); // Ultra-deep Obsidian Navy
  static const Color deepNavy = Color(0xFF131F37); // Rich Slate Navy
  static const Color royalSapphire = Color(0xFF1E3A8A); // Blue 900 - Regal Highway Blue
  static const Color cobaltBlue = Color(0xFF1D4ED8); // Blue 700 - Vivid Primary
  static const Color electricCobalt = Color(0xFF2563EB); // Blue 600 - Dynamic Action
  static const Color azureSky = Color(0xFF0284C7); // Sky 600 - Telemetry & Badges
  static const Color cyanAccent = Color(0xFF06B6D4); // Cyan 500 - Neon Highway Sensor
  static const Color skyGlow = Color(0xFF38BDF8); // Sky 400 - Radiant Accent
  static const Color lightIceBlue = Color(0xFFF0F7FF); // Clean Ice Blue Surface
  static const Color frostBlue = Color(0xFFE0F2FE); // Highlight Badges
  static const Color surfaceCanvas = Color(0xFFF4F7FB); // Executive Background Canvas
  static const Color champagneAmber = Color(0xFFF59E0B); // Warm Metallic Gold
  static const Color champagneGold = Color(0xFFD97706); // Amber Accent

  // Legacy aliases for seamless backwards-compatibility
  static const Color forestGreen = royalSapphire;
  static const Color deepGreen = midnightNavy;
  static const Color royalCobalt = electricCobalt;
  static const Color teal = azureSky;
  static const Color amberGold = Color(0xFFD97706);
  static const Color amberGoldLight = Color(0xFFFEF3C7);
  static const Color mint = lightIceBlue;
  static const Color lightMint = surfaceCanvas;

  static const Color orange = Color(0xFFD97706);
  static const Color darkNavy = midnightNavy;
  static const Color textSecondary = Color(0xFF64748B);

  static const Color primary = royalSapphire;
  static const Color secondary = electricCobalt;
  static const Color accent = champagneGold;
  static const Color textPrimary = midnightNavy;
  static const Color white = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF93C5FD);
  static const Color danger = Color(0xFFEF4444);
  static const Color crimsonRed = Color(0xFFEF4444);
  static const Color alertAmber = champagneAmber;
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFFD1FAE5);
  static const Color subtleGrey = Color(0xFF94A3B8);

  // Executive Multi-Tone Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E3A8A),
      Color(0xFF1D4ED8),
      Color(0xFF2563EB),
    ],
  );

  static const LinearGradient commandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
  );

  static const LinearGradient activeTabGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
    ],
  );

  static const LinearGradient amberSunGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF59E0B),
      Color(0xFFD97706),
    ],
  );

  static const LinearGradient indigoMoonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A1128),
      Color(0xFF1E3A8A),
    ],
  );

  static const LinearGradient alertPillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEFF6FF),
      Color(0xFFDBEAFE),
    ],
  );

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