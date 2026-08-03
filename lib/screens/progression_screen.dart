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
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _data!.isEmpty
                  ? const EmptyView(icon: Icons.show_chart, message: 'Sin datos todavía.\nSincroniza para ver tu evolución.')
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
        ...pts.reversed.map((p) {
          final pos = (p['finish_pos'] as num).toInt();
          final Color posColor = pos == 1 ? AppColors.gold
              : pos <= 3 ? AppColors.green : AppColors.text;
          final rating = (p['rating'] as num).round();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceAlt),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [posColor.withValues(alpha: 0.28),
                        posColor.withValues(alpha: 0.10)],
                  ),
                  border: Border.all(
                      color: posColor.withValues(alpha: 0.5), width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text('P$pos',
                    style: TextStyle(color: posColor, fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['track']}',
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.textDim, size: 11),
                        const SizedBox(width: 4),
                        Text(fmtDate(p['date']),
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 11)),
                      ]),
                    ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('RATING',
                    style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6)),
                Text('$rating',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
              ]),
            ]),
          );
        }),
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
