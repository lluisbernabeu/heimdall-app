import 'package:flutter/material.dart';
import '../theme.dart';

/// BÚSQUEDA — la forma moderna de encontrar cualquier cosa en Heimdall.
/// Nada de índices permanentes: una lupa en la barra superior y, cuando la
/// tocas, escribes lo que buscas y te lleva directo. Estilo spotlight.
void showFeatureSearch(BuildContext context, void Function(int) onGoToTab) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeatureSearchSheet(onGoToTab: onGoToTab),
  );
}

class _FeatureSearchSheet extends StatefulWidget {
  final void Function(int) onGoToTab;
  const _FeatureSearchSheet({required this.onGoToTab});
  @override
  State<_FeatureSearchSheet> createState() => _FeatureSearchSheetState();
}

class _FeatureSearchSheetState extends State<_FeatureSearchSheet> {
  String _q = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(String route) {
    Navigator.of(context).pop();
    if (route.startsWith('tab:')) {
      widget.onGoToTab(int.parse(route.substring(4)));
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _Feature.all;
    final filtered = _q.trim().isEmpty
        ? items
        : [
            for (final f in items)
              if (f.title.toLowerCase().contains(_q.toLowerCase()) ||
                  f.sub.toLowerCase().contains(_q.toLowerCase()))
                f
          ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.62,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(children: [
          // asa
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textDim.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.text, fontSize: 16),
            decoration: InputDecoration(
              hintText: '¿Qué quieres ver? (ej. sectores, logros…)',
              hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold),
              suffixIcon: _q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textDim),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _q = '');
                      })
                  : null,
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: AppColors.textDim)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final f = filtered[i];
                      return InkWell(
                        onTap: () => _go(f.route),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(f.icon, color: AppColors.gold, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(f.title,
                                    style: const TextStyle(
                                        color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                                Text(f.sub,
                                    style: const TextStyle(
                                        color: AppColors.textDim, fontSize: 11),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textDim, size: 20),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String sub;
  final String route;
  const _Feature(this.icon, this.title, this.sub, this.route);

  static final List<_Feature> all = [
    const _Feature(Icons.today_rounded, 'Calendario', 'Próximas carreras y estado de LFM', 'tab:1'),
    const _Feature(Icons.history_rounded, 'Carreras', 'Historial completo con replay', 'tab:2'),
    const _Feature(Icons.emoji_events_rounded, 'Clasificación', 'Tu posición en el campeonato', '/profile/standings'),
    const _Feature(Icons.military_tech_rounded, 'Logros', 'Progreso y rating por sim', '/profile/achievements'),
    const _Feature(Icons.timer_outlined, 'Sectores', 'Dónde pierdes el tiempo', '/analysis/sectors'),
    const _Feature(Icons.map_outlined, 'Circuito', 'Tu vuelta vs el récord', '/analysis/circuit'),
    const _Feature(Icons.speed_rounded, 'Consistencia', 'Regularidad de tus vueltas', '/analysis/consistency'),
    const _Feature(Icons.report_rounded, 'Incidentes', 'En qué te estrellas y cuánto cuesta', '/analysis/incidents'),
    const _Feature(Icons.show_chart_rounded, 'Progresión', 'Evolución de rating y SR', '/analysis/progression'),
    const _Feature(Icons.compare_arrows_rounded, 'Comparar', 'Tú vs otros pilotos', '/analysis/compare'),
    const _Feature(Icons.menu_book_rounded, 'Glosario', 'Qué significa cada cifra', '/glossary'),
  ];
}
