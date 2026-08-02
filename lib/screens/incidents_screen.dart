import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Incidentes — responde a "¿En qué te estrellas?".
/// Muestra el patrón dominante (qué tipo de incidente es tu problema),
/// la distribución por minuto, y permite entrar en cada carrera para ver
/// el detalle vuelta a vuelta.
class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await ApiClient.get('/api/me');
      final pid = ((me['profiles'] as List).first as Map)['id'] as int;
      final data = await ApiClient.get('/api/profile/$pid/incidents');
      setState(() { _data = Map<String, dynamic>.from(data as Map); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String typeLabel(String code) {
    switch (code) {
      case 'C': return 'Cut ✂️';
      case 'D': return 'Contacto 💥';
      case 'O': return 'Fuera 🚧';
      case 'R': return 'Relaunch 🔁';
      default: return code;
    }
  }

  String typeName(String code) {
    switch (code) {
      case 'C': return 'Cut';
      case 'D': return 'Contacto';
      case 'O': return 'Fuera de pista';
      case 'R': return 'Relaunch';
      default: return code;
    }
  }

  Color typeColor(String code) {
    switch (code) {
      case 'D': return AppColors.red;
      case 'C': return AppColors.gold;
      case 'O': return AppColors.cyan;
      default: return AppColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incidentes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _body(),
    );
  }

  Widget _body() {
    final byMinute = Map<String, dynamic>.from(_data!['by_minute'] as Map? ?? {});
    final byType = Map<String, dynamic>.from(_data!['by_type'] as Map? ?? {});
    final byRace = (_data!['by_race'] as List? ?? []);
    final total = (_data!['total'] as num?)?.toInt() ?? 0;
    final maxCount = byMinute.values.fold<int>(0,
        (a, b) => (b as num).toInt() > a ? b.toInt() : a);

    // patrón dominante
    String? dominant;
    if (byType.isNotEmpty) {
      final top = byType.entries.reduce((a, b) =>
          (b.value as num).toInt() > (a.value as num).toInt() ? b : a);
      final pct = ((top.value as num).toDouble() / (total == 0 ? 1 : total)) * 100;
      dominant = '${typeName(top.key)} (${top.value} de $total · ${pct.toStringAsFixed(0)}%)';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('¿En qué te estrellas?',
            style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Estos son tus incidentes en todas las carreras. Entra en una carrera para ver cada golpe vuelta a vuelta.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4)),
        const SizedBox(height: 12),
        if (dominant != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.45)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TU PATRÓN DOMINANTE', style: TextStyle(color: AppColors.textDim, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Text(dominant, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Saber qué tipo de incidente es el más común es el primer paso para corregirlo en pista.',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
            ]),
          ),
        Row(children: [
          Expanded(child: _BigCard(label: 'Total incidentes', value: '$total', color: AppColors.red)),
          Expanded(child: _BigCard(label: 'Tipos distintos', value: '${byType.keys.length}', color: AppColors.cyan)),
        ]),
        const SizedBox(height: 16),
        const Text('Cuándo pasan (minuto de carrera)',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceAlt),
          ),
          child: Column(
            children: [
              for (int minute = 0; minute <= 25; minute++)
                if (byMinute.containsKey('$minute'))
                  Row(children: [
                    SizedBox(
                      width: 44,
                      child: Text('${minute}m',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                    ),
                    Expanded(
                      child: Stack(children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: maxCount == 0 ? 0 : ((byMinute['$minute'] as num).toDouble() / maxCount).clamp(0.05, 1.0),
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [(byMinute['$minute'] as num) >= 2
                                    ? AppColors.red : AppColors.gold,
                                    (byMinute['$minute'] as num) >= 2
                                    ? AppColors.red.withValues(alpha: 0.7)
                                    : AppColors.gold.withValues(alpha: 0.7)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text('${byMinute['$minute']}',
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                    ),
                  ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Por carrera (toca para ver el detalle)',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...byRace.map((raw) {
          final r = Map<String, dynamic>.from(raw as Map);
          final counts = Map<String, dynamic>.from(r['counts'] as Map? ?? {});
          final chips = counts.entries.map((e) =>
              '${typeLabel(e.key)}: ${e.value}').join(' · ');
          final totalR = (r['total'] as num?)?.toInt() ?? 0;
          return InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RaceIncidentsScreen(
                    raceId: (r['race_id'] as num?)?.toInt() ?? 0,
                    title: '${r['track_name']}'))),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: totalR >= 4
                      ? AppColors.red.withValues(alpha: 0.35)
                      : AppColors.surfaceAlt,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: totalR >= 4
                        ? AppColors.red.withValues(alpha: 0.13)
                        : AppColors.gold.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text('$totalR',
                      style: TextStyle(
                        color: totalR >= 4 ? AppColors.red : AppColors.gold,
                        fontSize: 17, fontWeight: FontWeight.w900,
                      )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['track_name'] ?? '—'}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text,
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${r['event_name'] != null && r['event_name'] != '' ? '${r['event_name']} · ' : ''}${fmtDateHora(r['race_date'])}'
                        '${r['finish_pos'] != null ? ' · P${r['finish_pos']}' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(chips,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                  ]),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppColors.textDim, size: 20),
              ]),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text('Tipos: C=cut (la vuelta no cuenta) · D=contacto/daño · O=fuera de pista · R=relaunch (reinicio del servidor)',
            style: TextStyle(color: AppColors.textDim, fontSize: 11)),
      ],
    );
  }
}

/// Detalle de incidentes de UNA carrera — vuelta a vuelta.
class RaceIncidentsScreen extends StatefulWidget {
  final int raceId;
  final String title;
  const RaceIncidentsScreen({super.key, required this.raceId, required this.title});
  @override
  State<RaceIncidentsScreen> createState() => _RaceIncidentsScreenState();
}

class _RaceIncidentsScreenState extends State<RaceIncidentsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await ApiClient.get('/api/me');
      final pid = ((me['profiles'] as List).first as Map)['id'] as int;
      final data = await ApiClient.get('/api/profile/$pid/incidents/${widget.raceId}');
      setState(() { _data = Map<String, dynamic>.from(data as Map); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String typeLabel(String code) {
    switch (code) {
      case 'C': return 'Cut ✂️';
      case 'D': return 'Contacto 💥';
      case 'O': return 'Fuera 🚧';
      case 'R': return 'Relaunch 🔁';
      default: return code;
    }
  }

  Color typeColor(String code) {
    switch (code) {
      case 'D': return AppColors.red;
      case 'C': return AppColors.gold;
      case 'O': return AppColors.cyan;
      default: return AppColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _body(),
    );
  }

  Widget _body() {
    final race = Map<String, dynamic>.from(_data!['race'] as Map? ?? {});
    final items = (_data!['items'] as List? ?? []);
    final counts = Map<String, dynamic>.from(_data!['counts'] as Map? ?? {});
    final total = (_data!['total'] as num?)?.toInt() ?? 0;

    // agrupar por vuelta
    final byLap = <int, List<Map<String, dynamic>>>{};
    for (final raw in items) {
      final it = Map<String, dynamic>.from(raw as Map);
      final lap = (it['lap'] as num?)?.toInt();
      byLap.putIfAbsent(lap ?? 0, () => []).add(it);
    }
    final lapsSorted = byLap.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _BigCard(label: 'Incidentes', value: '$total', color: AppColors.red)),
          Expanded(child: _BigCard(
              label: 'P${race['finish_pos'] ?? '—'} · ${fmtDateHora(race['race_date'])}',
              value: '${race['laps'] ?? '—'} vueltas', color: AppColors.cyan)),
        ]),
        const SizedBox(height: 12),
        if (counts.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in counts.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor(e.key).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: typeColor(e.key).withValues(alpha: 0.45)),
                ),
                child: Text('${typeLabel(e.key)}: ${e.value}',
                    style: TextStyle(color: typeColor(e.key), fontWeight: FontWeight.w700)),
              ),
          ]),
        const SizedBox(height: 16),
        const Text('Vuelta a vuelta',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (lapsSorted.isEmpty)
          const Text('No hay incidentes registrados en esta carrera.',
              style: TextStyle(color: AppColors.textDim))
        else
          ...lapsSorted.map((lap) {
            final lapItems = byLap[lap]!;
            final lapColor = lapItems.length >= 2 ? AppColors.red : AppColors.gold;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lapColor.withValues(alpha: 0.35)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Vuelta $lap',
                      style: TextStyle(color: lapColor, fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Text('${lapItems.length} incidente${lapItems.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                ]),
                const SizedBox(height: 6),
                ...lapItems.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.circle, color: typeColor(it['type']?.toString() ?? ''), size: 8),
                    const SizedBox(width: 8),
                    Text(typeLabel(it['type']?.toString() ?? '?'),
                        style: const TextStyle(color: AppColors.text, fontSize: 12)),
                    const Spacer(),
                    Text('min ${_fmtMinute(it['server_time_ms'])}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                  ]),
                )),
              ]),
            );
          }),
        const SizedBox(height: 12),
        const Text('Consejo: si una vuelta concentra 2+ incidentes, probablemente fue un toque o una pérdida de control puntual. Revísala en el detalle de carrera.',
            style: TextStyle(color: AppColors.textDim, fontSize: 11, height: 1.4)),
      ],
    );
  }

  String _fmtMinute(Object? serverMs) {
    final ms = (serverMs as num?)?.toInt();
    if (ms == null) return '—';
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _BigCard extends StatelessWidget {
  final String label; final String value; final Color color;
  const _BigCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      ]),
    );
  }
}
