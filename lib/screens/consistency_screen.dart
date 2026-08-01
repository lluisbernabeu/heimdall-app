import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Consistencia: desviación estándar de tiempos por carrera.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consistencia')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _data!.isEmpty
                  ? const Center(child: Text('Sin datos', style: TextStyle(color: AppColors.textDim)))
                  : _body(),
    );
  }

  Widget _body() {
    final rows = _data!;
    final stds = rows.map((r) => (r['std_ms'] as num).toDouble()).toList();
    final maxStd = stds.reduce((a, b) => a > b ? a : b);
    final avgStd = stds.reduce((a, b) => a + b) / stds.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _KpiCard(label: 'Media desv. estándar', value: '${(avgStd / 1000).toStringAsFixed(3)}s', color: AppColors.cyan)),
          Expanded(child: _KpiCard(label: 'Mejor consistencia', value: '${(stds.reduce((a, b) => a < b ? a : b) / 1000).toStringAsFixed(3)}s', color: AppColors.green)),
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
        const Text('Desviación estándar por carrera (menor = más consistente)',
            style: TextStyle(color: AppColors.textDim, fontSize: 11)),
        const SizedBox(height: 16),
        ...rows.reversed.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final std = (m['std_ms'] as num).toDouble();
          return ListTile(
            dense: true,
            leading: Icon(Icons.speed, color: std <= avgStd ? AppColors.green : AppColors.gold, size: 18),
            title: Text('${m['track_name']}', style: const TextStyle(color: AppColors.text, fontSize: 13)),
            subtitle: Text('${m['race_date']?.toString().substring(0, 10)} · ${m['laps']} vueltas',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
            trailing: Text('σ ${(std / 1000).toStringAsFixed(3)}s',
                style: TextStyle(color: std <= avgStd ? AppColors.green : AppColors.gold,
                    fontWeight: FontWeight.w800, fontSize: 12)),
          );
        }),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label; final String value; final Color color;
  const _KpiCard({required this.label, required this.value, required this.color});
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
