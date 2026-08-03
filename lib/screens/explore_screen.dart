import 'package:flutter/material.dart';
import '../theme.dart';

/// EXPLORAR — el mapa completo de Heimdall.
///
/// Resuelve el problema de descubribilidad: TODAS las features de la app
/// visibles en una sola pantalla, cada una a 1 tap. Cero submenús.
/// Estructura: secciones por flujo (Carreras / Rendimiento / Competición / Guía).
class ExploreScreen extends StatelessWidget {
  /// Cambia a la pestaña de fondo indicada (0=Explorar, 1=Calendario,
  /// 2=Carreras, 3=Análisis, 4=Perfil).
  final void Function(int tab) onGoToTab;
  const ExploreScreen({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        // ---- Cabecera del hub ----
        const _ExploreHeader(),
        const SizedBox(height: 18),

        // ---- Sección: Carreras (flujos de fondo) ----
        const _SectionLabel(icon: Icons.flag_rounded, label: 'Carreras'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _FeatureCard(
              icon: Icons.today_rounded,
              title: 'Calendario',
              sub: 'Próximas carreras y estado de LFM',
              onTap: () => onGoToTab(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FeatureCard(
              icon: Icons.history_rounded,
              title: 'Historial',
              sub: 'Todas tus carreras, con replay y datos',
              onTap: () => onGoToTab(2),
            ),
          ),
        ]),
        const SizedBox(height: 18),

        // ---- Sección: Rendimiento (herramientas de análisis) ----
        const _SectionLabel(icon: Icons.analytics_rounded, label: 'Rendimiento'),
        const SizedBox(height: 4),
        const Text(
          'Cada herramienta responde una pregunta sobre tu pilotaje.',
          style: TextStyle(color: AppColors.textDim, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        _FeatureRow(
          icon: Icons.timer_outlined,
          title: 'Sectores',
          sub: '¿Dónde pierdes el tiempo? S1/S2/S3 vs el más rápido del split',
          onTap: () => _push(context, '/analysis/sectors'),
        ),
        _FeatureRow(
          icon: Icons.map_outlined,
          title: 'Circuito',
          sub: '¿Cómo estás en cada trazado? Tu vuelta vs el récord, con mapa',
          onTap: () => _push(context, '/analysis/circuit'),
        ),
        _FeatureRow(
          icon: Icons.speed_rounded,
          title: 'Consistencia',
          sub: '¿Qué tan regulares son tus vueltas?',
          onTap: () => _push(context, '/analysis/consistency'),
        ),
        _FeatureRow(
          icon: Icons.report_rounded,
          title: 'Incidentes',
          sub: '¿En qué te estrellas y cuánto te cuesta en SR?',
          onTap: () => _push(context, '/analysis/incidents'),
        ),
        _FeatureRow(
          icon: Icons.show_chart_rounded,
          title: 'Progresión',
          sub: '¿Vas a mejor o a peor? Evolución de rating y SR',
          onTap: () => _push(context, '/analysis/progression'),
        ),
        _FeatureRow(
          icon: Icons.compare_arrows_rounded,
          title: 'Comparar',
          sub: '¿Cómo estás frente a otros pilotos?',
          onTap: () => _push(context, '/analysis/compare'),
        ),
        const SizedBox(height: 18),

        // ---- Sección: Competición (lo que molaba escondido) ----
        const _SectionLabel(icon: Icons.emoji_events_rounded, label: 'Competición'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _FeatureCard(
              icon: Icons.emoji_events_rounded,
              title: 'Clasificación',
              sub: 'Tu posición en el campeonato',
              onTap: () => _push(context, '/profile/standings'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FeatureCard(
              icon: Icons.military_tech_rounded,
              title: 'Logros',
              sub: 'Progreso y rating por sim',
              onTap: () => _push(context, '/profile/achievements'),
            ),
          ),
        ]),
        const SizedBox(height: 18),

        // ---- Sección: Guía ----
        const _SectionLabel(icon: Icons.menu_book_rounded, label: 'Guía'),
        const SizedBox(height: 10),
        _FeatureRow(
          icon: Icons.menu_book_outlined,
          title: '¿Qué significa cada cosa?',
          sub: 'Rating, SR, splits, incidentes, SOF… el glosario completo',
          onTap: () => _push(context, '/glossary'),
        ),
      ],
    );
  }

  void _push(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }
}

// =====================================================================
// Cabecera del hub
// =====================================================================
class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlt, AppColors.bg],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.goldLight, AppColors.gold],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.explore_rounded, color: AppColors.bg, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('EXPLORAR HEIMDALL',
                style: TextStyle(color: AppColors.gold, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            const SizedBox(height: 4),
            const Text('Todo lo que puedes hacer, a un toque.',
                style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('11 herramientas · sin menús escondidos',
                style: TextStyle(color: AppColors.textDim.withValues(alpha: 0.9), fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
// Etiqueta de sección
// =====================================================================
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.gold, size: 17),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
    ]);
  }
}

// =====================================================================
// Tarjeta grande (grid 2 columnas): icono + título + descripción
// =====================================================================
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _FeatureCard({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 128,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.surfaceAlt, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.goldLight, AppColors.gold],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.bg, size: 21),
            ),
            const Spacer(),
            Text(title,
                style: const TextStyle(color: AppColors.text, fontSize: 14.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(color: AppColors.textDim, fontSize: 10.5),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================
// Fila de feature (lista vertical): más detalle, mismo 1 tap
// =====================================================================
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _FeatureRow({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceAlt),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11), maxLines: 2),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textDim, size: 20),
        ]),
      ),
    );
  }
}
