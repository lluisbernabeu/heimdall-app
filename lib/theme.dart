import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Heimdall — identidad "OJO DE HEIMDALL": negro profundo + oro antiguo +
/// runas. El vigilante de Asgard: oscuro, elegante, poderoso.
class AppColors {
  static const Color bg = Color(0xFF0A0805);       // negro carbón cálido
  static const Color surface = Color(0xFF16110A);  // tarjetas (marrón noche)
  static const Color surfaceAlt = Color(0xFF221A10); // relieve
  static const Color gold = Color(0xFFE8A33D);     // oro antiguo Heimdall
  static const Color goldLight = Color(0xFFF5C469); // oro brillante
  static const Color goldDeep = Color(0xFFB87A1E); // oro oscuro (bordes)
  static const Color cyan = Color(0xFF5EC8D8);     // cian telemetría (atenuado)
  static const Color red = Color(0xFFE85A4A);      // incidentes/negativo
  static const Color green = Color(0xFF7FD98A);    // positivo/SR
  static const Color blue = Color(0xFFB8A57A);     // resultado neutro (bronce apagado)
  static const Color text = Color(0xFFF0E4CF);     // marfil cálido
  static const Color textDim = Color(0xFF9C8A68);  // dorado apagado
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'serif',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.gold,
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
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // esquinas afiladas estilo runa
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.16)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      hintStyle: const TextStyle(color: AppColors.textDim),
      prefixIconColor: AppColors.gold,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.goldLight,
      unselectedLabelColor: AppColors.textDim,
      indicatorColor: AppColors.gold,
    ),
    dividerColor: AppColors.surfaceAlt,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.gold.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.goldLight : AppColors.textDim,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? AppColors.goldLight : AppColors.textDim,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          letterSpacing: 0.4,
        );
      }),
    ),
  );
}

/// Botón principal con degradado dorado y esquinas afiladas (marca Heimdall).
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
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5C469), Color(0xFFE8A33D), Color(0xFFB87A1E)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: (loading || onPressed == null) ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.bg))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: AppColors.bg, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(label,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: AppColors.bg)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Fondo con runas nórdicas sutiles (estrellas de 8 puntas / vegvisir).
/// Se dibuja con CustomPainter para no depender de assets.
class RuneBackground extends StatelessWidget {
  final Widget child;
  const RuneBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RunePainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class _RunePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8A33D).withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const spacing = 96.0;
    final w = size.width, h = size.height;
    for (double y = spacing / 2; y < h + spacing; y += spacing) {
      for (double x = spacing / 2; x < w + spacing; x += spacing) {
        _drawRune(canvas, paint, x, y);
      }
    }
    // viñeta oscura para dar profundidad
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignette);
  }

  void _drawRune(Canvas canvas, Paint paint, double x, double y) {
    final r = 7.0;
    // estrella de 8 puntas (vegvisir simplificado)
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * 3.14159 / 4;
      final px = x + r * 1.6 * math.cos(angle);
      final py = y + r * 1.6 * math.sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    // segundo anillo
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(x, y), r * 0.9, paint);
    // trazo de runa (línea vertical + ramas)
    canvas.drawLine(Offset(x, y - r * 1.1), Offset(x, y + r * 1.1), paint);
    canvas.drawLine(Offset(x, y - r * 0.5), Offset(x + r * 0.9, y - r * 1.1), paint);
    canvas.drawLine(Offset(x, y + r * 0.5), Offset(x - r * 0.9, y + r * 1.1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo de Heimdall — runa del vigilante (ᚺ + ojo) dorada sobre negro.
class HeimdallLogo extends StatelessWidget {
  final double size;
  const HeimdallLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A10), Color(0xFF0A0805)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: CustomPaint(
          painter: _RuneEyePainter(),
          size: Size.square(size * 0.72),
        ),
      ),
    );
  }
}

/// El ojo de Heimdall — minimalista: anillo exterior, ojo almendrado limpio
/// y la runa Hagalaz (ᚺ) auténtica en el centro (3 trazos, legible).
class _RuneEyePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gold = Paint()
      ..color = const Color(0xFFF5C469)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // anillo exterior (sello)
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.44, gold);

    // ojo almendrado limpio, sin pupilas ni rellenos
    final eye = Path()
      ..moveTo(w * 0.10, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.16, w * 0.90, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.84, w * 0.10, h * 0.5);
    canvas.drawPath(eye, gold);

    // runa Hagalaz ᚺ (3 trazos: 2 verticales + diagonal central)
    final cx = w * 0.5;
    canvas.drawLine(Offset(cx - w * 0.16, h * 0.32), Offset(cx - w * 0.16, h * 0.68), gold);
    canvas.drawLine(Offset(cx + w * 0.16, h * 0.32), Offset(cx + w * 0.16, h * 0.68), gold);
    canvas.drawLine(Offset(cx - w * 0.16, h * 0.44), Offset(cx + w * 0.16, h * 0.56), gold);
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

/// Formatea milisegundos de vuelta como "1:37.056" (o "—" si null).
String fmtLap(num? ms) {
  if (ms == null) return '—';
  final total = ms.round();
  final m = total ~/ 60000;
  final s = (total % 60000) / 1000.0;
  return '$m:${s.toStringAsFixed(3).padLeft(6, '0')}';
}

/// Radio estándar de tarjetas — la app usa esquinas "runa" (más afiladas
/// que el Material por defecto). Un único valor evita el popurrí visual.
class AppRadius {
  static const double card = 14;   // tarjetas principales
  static const double small = 10;  // chips, badges, mini-contenedores
  static const double button = 6;  // botones (esquinas muy afiladas)
}

/// Estado de carga estándar para cualquier pantalla.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppColors.gold));
  }
}

/// Estado de error estándar: mensaje + botón reintentar.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, color: AppColors.red, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 13)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Estado vacío estándar: icono + mensaje centrado.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyView({super.key, required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.textDim, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.4)),
        ]),
      ),
    );
  }
}

/// Título de sección estándar (negrita marfil + subtítulo apagado).
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(subtitle!,
            style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4)),
      ],
    ]);
  }
}

/// Tarjeta de métrica — valor grande de color + etiqueta pequeña.
/// Unifica _KpiCard / _BigCard / _StatCell: la misma pieza en todas partes.
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool compact;
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: compact ? 15 : 20,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: compact ? 9 : 10)),
      ]),
    );
  }
}

/// Chip informativo estándar (circuito, split, categoría...).
class InfoChip extends StatelessWidget {
  final String text;
  final Color color;
  const InfoChip(this.text, {super.key, this.color = AppColors.gold});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
