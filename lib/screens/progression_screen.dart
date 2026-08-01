import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Progresión de rating y SR a lo largo de las carreras.
class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({super.key});
  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen> {
  List<dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await ApiClient.get('/api/me');
      final pid = ((me['profiles'] as List).first as Map)['id'] as int;
      final data = await ApiClient.get('/api/profile/$pid/progression');
      setState(() { _data = data as List; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progresión')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _data!.isEmpty
                  ? const Center(child: Text('Sin datos', style: TextStyle(color: AppColors.textDim)))
                  : _chart(),
    );
  }

  Widget _chart() {
    final pts = _data!;
    final ratings = pts.map((p) => (p['rating'] as num).toDouble()).toList();
    final srs = pts.map((p) => (p['sr'] as num).toDouble()).toList();
    double minR = ratings.reduce((a, b) => a < b ? a : b) - 50;
    double maxR = ratings.reduce((a, b) => a > b ? a : b) + 50;
    double minS = srs.reduce((a, b) => a < b ? a : b) - 0.5;
    double maxS = srs.reduce((a, b) => a > b ? a : b) + 0.5;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Rating',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(height: 200, child: _lineChart(ratings, minR, maxR, AppColors.gold)),
        const SizedBox(height: 24),
        const Text('Safety Rating',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(height: 200, child: _lineChart(srs, minS, maxS, AppColors.green)),
        const SizedBox(height: 24),
        ...pts.reversed.map((p) => ListTile(
          dense: true,
          leading: Icon(Icons.flag, color: (p['finish_pos'] as num) <= 3
              ? AppColors.gold : AppColors.textDim, size: 18),
          title: Text('${p['track']}',
              style: const TextStyle(color: AppColors.text, fontSize: 13)),
          subtitle: Text('${p['date']?.toString().substring(0, 10)} · P${p['finish_pos']}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          trailing: Text('${(p['rating'] as num).round()}',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
        )),
      ],
    );
  }

  Widget _lineChart(List<double> vals, double minY, double maxY, Color color) {
    final spots = <FlSpot>[
      for (int i = 0; i < vals.length; i++) FlSpot(i.toDouble(), vals[i]),
    ];
    return LineChart(LineChartData(
      minY: minY, maxY: maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surfaceAlt, strokeWidth: 1)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44,
            getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                style: TextStyle(color: AppColors.textDim, fontSize: 10)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2.5,
          isCurved: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true,
              color: color.withValues(alpha: 0.12)),
        ),
      ],
    ));
  }
}
