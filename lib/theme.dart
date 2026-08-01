import 'package:flutter/material.dart';

/// Heimdall — tema visual: azul noche + dorado + cian telemétrico.
class AppColors {
  static const Color bg = Color(0xFF0A1420);       // azul noche profundo
  static const Color surface = Color(0xFF111E2E);  // tarjetas
  static const Color surfaceAlt = Color(0xFF16283C);
  static const Color gold = Color(0xFFE8A33D);     // dorado Heimdall
  static const Color goldLight = Color(0xFFF5C469);
  static const Color cyan = Color(0xFF3DD6E8);     // cian telemetría
  static const Color red = Color(0xFFE83D4A);      // incidentes/negativo
  static const Color green = Color(0xFF3DE87A);    // positivo/SR
  static const Color blue = Color(0xFF3D8BE8);     // resultado neutro
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.10)),
      ),
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
      prefixIconColor: AppColors.gold,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
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

/// Botón principal con degradado dorado (marca Heimdall).
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const GoldButton({super.key, required this.label, this.onPressed,
      this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5C469), Color(0xFFE8A33D), Color(0xFFD08F28)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: (loading || onPressed == null) ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0A1420)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: const Color(0xFF0A1420), size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(label,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: Color(0xFF0A1420))),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Logo de Heimdall — bandera a cuadros dorada dibujada con CustomPainter
/// (contraste nítido a cualquier tamaño, sin depender de assets).
class HeimdallLogo extends StatelessWidget {
  final double size;
  const HeimdallLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2C44), Color(0xFF0D1B2E)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: CustomPaint(
          painter: _CheckerFlagPainter(),
          size: Size.square(size * 0.76),
        ),
      ),
    );
  }
}

/// Bandera a cuadros: cuadros dorados + azul noche, asta dorada.
class _CheckerFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pole = Paint()
      ..color = const Color(0xFFF5C469)
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    // asta
    canvas.drawLine(
        Offset(w * 0.06, h * 0.02), Offset(w * 0.06, h * 0.98), pole);
    // bandera (rectángulo con ligera inclinación)
    final flagLeft = w * 0.12;
    final flagTop = h * 0.08;
    final flagW = w * 0.82;
    final flagH = h * 0.62;
    const cols = 5, rows = 4;
    final cellW = flagW / cols, cellH = flagH / rows;
    final light = Paint()..color = const Color(0xFFF5C469);   // dorado brillante
    final dark = Paint()..color = const Color(0xFF0D1B2E);    // azul noche
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
            flagLeft + c * cellW, flagTop + r * cellH, cellW, cellH);
        canvas.drawRect(rect, (r + c) % 2 == 0 ? light : dark);
      }
    }
    // contorno de la bandera
    canvas.drawRect(
        Rect.fromLTWH(flagLeft, flagTop, flagW, flagH),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02
          ..color = const Color(0xFFF5C469));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Formatea '2026-07-31T...' o '2026-07-31' como '31 jul 2026' (es-ES).
String fmtDate(Object? iso) {
  if (iso == null) return '';
  final s = iso.toString();
  if (s.length < 10) return s;
  final y = s.substring(0, 4);
  final m = s.substring(5, 7);
  final d = s.substring(8, 10);
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final mi = int.tryParse(m);
  if (mi == null || mi < 1 || mi > 12) return s.substring(0, 10);
  return '$d ${meses[mi - 1]} $y';
}

/// Fecha + hora: "20 jul 2026 · 18:20". Para distinguir carreras del mismo día.
String fmtDateHora(Object? iso) {
  if (iso == null) return '';
  final base = fmtDate(iso);
  final s = iso.toString();
  if (s.length >= 16) {
    final hh = s.substring(11, 13);
    final mm = s.substring(14, 16);
    return '$base · $hh:$mm';
  }
  return base;
}
