import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Consistencia — responde a "¿Qué tan regulares son tus vueltas?".
/// Explica la desviación estándar en cristiano: es cuánto varían tus
/// tiempos entre vueltas. Menor = más constante. Muestra también el
/// spread (mejor vs peor vuelta) para ver la vuelta que rompió la racha.
class ConsistencyScreen extends StatefulWidget {
  const ConsistencyScreen({super.key});
  @override
  State<ConsistencyScreen> createState() => _ConsistencyScreenState();
}

class _ConsistencyScreenState extends State<ConsistencyScreen> {
  List<dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await ApiClient.get('/api/me');
      final pid = ((me['profiles'] as List).first as Map)['id'] as int;
      final data = await ApiClient.get('/api/profile/$pid/consistency');
      setState(() { _data = data as List; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _fmt(num? ms) => fmtLap(ms);

  /// Categoría: <1s muy consistente, <2.5s normal, >=2.5s irregular.
  /// Semántica unificada: verde=bueno, dorado=aviso, rojo=malo.
  (String, Color) _verdict(double stdMs) {
    if (stdMs < 1000) return ('Muy consistente', AppColors.green);
    if (stdMs < 2500) return ('Normal', AppColors.gold);
    return ('Irregular', AppColors.red);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consistencia')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _data!.isEmpty
                  ? const EmptyView(icon: Icons.speed, message: 'Sin datos todavía.\nSincroniza para analizar tu constancia.')
                  : _body(),
    );
  }

  Widget _body() {
    final rows = _data!;
    final stds = rows.map((r) => (r['std_ms'] as num).toDouble()).toList();
    final maxStd = stds.reduce((a, b) => a > b ? a : b);
    final avgStd = stds.reduce((a, b) => a + b) / stds.length;
    final bestStd = stds.reduce((a, b) => a < b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('¿Qué tan regulares son tus vueltas?',
            subtitle: 'La desviación estándar (σ) mide cuánto varían tus tiempos entre vueltas: cuanto más baja, más constante es tu ritmo. La vuelta 1 se ignora — la salida siempre es un caos y no refleja tu ritmo real.'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(label: 'Media σ', value: '${(avgStd / 1000).toStringAsFixed(3)}s', color: AppColors.gold)),
          Expanded(child: StatCard(label: 'Tu mejor racha', value: '${(bestStd / 1000).toStringAsFixed(3)}s', color: AppColors.green)),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 180,
          child: BarChart(BarChartData(
            maxY: maxStd * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
                  getTitlesWidget: (v, meta) => Text((v / 1000).toStringAsFixed(2),
                      style: TextStyle(color: AppColors.textDim, fontSize: 9)))),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barGroups: [
              for (int i = 0; i < rows.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: (rows[i]['std_ms'] as num).toDouble(),
                    color: (rows[i]['std_ms'] as num).toDouble() <= avgStd
                        ? AppColors.green : AppColors.gold,
                    width: 6, borderRadius: BorderRadius.circular(3)),
                ]),
            ],
          )),
        ),
        const SizedBox(height: 8),
        const Text('σ por carrera · verde = más constante que tu media',
            style: TextStyle(color: AppColors.textDim, fontSize: 11)),
        const SizedBox(height: 16),
        ...rows.reversed.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final std = (m['std_ms'] as num).toDouble();
          final (vlabel, vcolor) = _verdict(std);
          final bestMs = (m['best_ms'] as num?)?.toDouble();
          final worstMs = (m['worst_ms'] as num?)?.toDouble();
          final spreadMs = (m['spread_ms'] as num?)?.toDouble();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vcolor.withValues(alpha: 0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: vcolor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.speed, color: vcolor, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['track_name']}',
                        style: const TextStyle(color: AppColors.text,
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${fmtDate(m['race_date'])} · ${m['laps']} vueltas'
                        '${(m['laps_total'] as num?)?.toInt() != null && (m['laps_total'] as num).toInt() != (m['laps'] as num).toInt() ? ' (${m['laps_total']} con salida)' : ''}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('σ ${(std / 1000).toStringAsFixed(3)}s',
                      style: TextStyle(color: vcolor, fontWeight: FontWeight.w900, fontSize: 13)),
                  Text(vlabel, style: TextStyle(color: AppColors.textDim, fontSize: 9)),
                ]),
              ]),
              const SizedBox(height: 8),
              if (bestMs != null && worstMs != null && spreadMs != null) ...[
                Text('Mejor vuelta ${_fmt(bestMs)} · peor ${_fmt(worstMs)} · diferencia ${(spreadMs / 1000).toStringAsFixed(2)}s',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                if (m['first_lap_ms'] != null)
                  Text('Vuelta 1 (salida): ${_fmt((m['first_lap_ms'] as num).toDouble())} · excluida de la σ',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
                if (spreadMs > 2500)
                  Text('⚠️ La diferencia entre tu mejor y peor vuelta es grande: hay una vuelta que se te fue. Revisa qué pasó (tráfico, incidente o pérdida de concentración).',
                      style: TextStyle(color: AppColors.gold, fontSize: 10.5, height: 1.35)),
              ],
            ]),
          );
        }),
      ],
    );
  }
}
