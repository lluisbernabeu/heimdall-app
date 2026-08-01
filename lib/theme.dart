import 'package:flutter/material.dart';

/// Heimdall — tema visual: azul noche + dorado + cian telemétrico.
class AppColors {
  static const Color bg = Color(0xFF0A1420);       // azul noche profundo
  static const Color surface = Color(0xFF111E2E);  // tarjetas
  static const Color surfaceAlt = Color(0xFF16283C);
  static const Color gold = Color(0xFFE8A33D);     // dorado Heimdall
  static const Color cyan = Color(0xFF3DD6E8);     // cian telemetría
  static const Color red = Color(0xFFE83D4A);      // incidentes/negativo
  static const Color green = Color(0xFF3DE87A);    // positivo/SR
  static const Color text = Color(0xFFE8EEF4);
  static const Color textDim = Color(0xFF8CA0B4);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      error: AppColors.red,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF0A1420),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      hintStyle: const TextStyle(color: AppColors.textDim),
      prefixIconColor: AppColors.textDim,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.gold,
      unselectedLabelColor: AppColors.textDim,
      indicatorColor: AppColors.gold,
    ),
    dividerColor: AppColors.surfaceAlt,
  );
}

/// Logo del cuerno de Heimdall (Gjallarhorn) — widget reutilizable.
class HeimdallLogo extends StatelessWidget {
  final double size;
  const HeimdallLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8A33D), Color(0xFFB97A1F)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.graphic_eq_rounded, color: const Color(0xFF0A1420), size: size * 0.55),
    );
  }
}
