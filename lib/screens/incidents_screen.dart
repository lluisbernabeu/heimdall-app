import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Heatmap de incidentes: en qué minuto y qué tipo.
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
    final total = (_data!['total'] as num?)?.toInt() ?? 0;
    final maxCount = byMinute.values.fold<int>(0,
        (a, b) => (b as num).toInt() > a ? b.toInt() : a);

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _BigCard(label: 'Total incidentes', value: '$total', color: AppColors.red)),
          Expanded(child: _BigCard(label: 'Tipos', value: '${byType.keys.length}', color: AppColors.cyan)),
        ]),
        const SizedBox(height: 16),
        const Text('Distribución por minuto de carrera',
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
        const Text('Por carrera',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...(_data!['by_race'] as List? ?? []).map((raw) {
          final r = Map<String, dynamic>.from(raw as Map);
          final counts = Map<String, dynamic>.from(r['counts'] as Map? ?? {});
          final chips = counts.entries.map((e) =>
              '${typeLabel(e.key)}: ${e.value}').join(' · ');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (r['total'] as num? ?? 0) >= 4
                    ? AppColors.red.withValues(alpha: 0.35)
                    : AppColors.surfaceAlt,
              ),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (r['total'] as num? ?? 0) >= 4
                      ? AppColors.red.withValues(alpha: 0.13)
                      : AppColors.gold.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text('${r['total'] ?? 0}',
                    style: TextStyle(
                      color: (r['total'] as num? ?? 0) >= 4
                          ? AppColors.red : AppColors.gold,
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
                ]),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(chips,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
              ),
            ]),
          );
        }),
        const SizedBox(height: 16),
        const Text('Tipos de incidente',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in byType.entries)
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
        const SizedBox(height: 12),
        const Text('Tipos: C=cut (la vuelta no cuenta) · D=contacto/daño · O=fuera de pista · R=relaunch (reinicio del servidor)',
            style: TextStyle(color: AppColors.textDim, fontSize: 11)),
      ],
    );
  }
}

class _BigCard extends StatelessWidget {
  final String label; final String value; final Color color;
  const _BigCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
      ]),
    );
  }
}
