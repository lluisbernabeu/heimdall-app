import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Detalle de una carrera: vueltas con sectores + delta vs el más rápido.
class RaceDetailScreen extends StatefulWidget {
  final int profileId;
  final int raceId;
  const RaceDetailScreen({super.key, required this.profileId, required this.raceId});
  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/api/profile/${widget.profileId}/races/${widget.raceId}');
      setState(() { _data = Map<String, dynamic>.from(data as Map); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _fmt(num? ms) {
    if (ms == null) return '—';
    final total = ms.round();
    final m = total ~/ 60000;
    final s = (total % 60000) / 1000.0;
    return '$m:${s.toStringAsFixed(3).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de carrera')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _body(),
    );
  }

  Widget _body() {
    final race = Map<String, dynamic>.from(_data!['race'] as Map);
    final pilots = (_data!['pilots'] as List? ?? []).cast<Map>();
    final lapChart = (_data!['lap_chart'] as List? ?? []).cast<Map>();
    final incidents = (_data!['incidents'] as List? ?? []).cast<Map>();
    final myUid = _data!['my_user_id'];
    final dateStr = race['race_date']?.toString();
    final dateShort = (dateStr != null && dateStr.length >= 10) ? dateStr.substring(0, 10) : '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cabecera carrera
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF16283C), Color(0xFF0D1B2E)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceAlt),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${race['track_name']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            Text('${race['event_name']} · $dateShort',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              _chip('P${race['finish_pos']}', AppColors.gold),
              _chip('Salida ${race['start_pos']}', AppColors.textDim),
              _chip('Split ${race['split']}', AppColors.cyan),
              if (race['best_lap'] != null) _chip('Mejor ${race['best_lap']}', AppColors.green),
              if (race['rating_change'] != null)
                _chip('Rtg ${(race['rating_change'] as num) >= 0 ? '+' : ''}${race['rating_change']}',
                    (race['rating_change'] as num) >= 0 ? AppColors.green : AppColors.red),
              if (race['sr_change'] != null)
                _chip('SR ${(race['sr_change'] as num) >= 0 ? '+' : ''}${race['sr_change']}',
                    (race['sr_change'] as num) >= 0 ? AppColors.green : AppColors.red),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Ranking del split (los que tienen vueltas)
        const Text('Ranking del split (mejor vuelta)',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...pilots.take(10).map((p) => ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: p['user_id'] == myUid
                ? AppColors.gold.withValues(alpha: 0.25)
                : AppColors.surfaceAlt,
            child: Text('${p['user_id'] == myUid ? '★' : (pilots.indexOf(p) + 1)}',
                style: TextStyle(color: p['user_id'] == myUid
                    ? AppColors.gold : AppColors.textDim, fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          title: Text('${p['name']}',
              style: TextStyle(color: p['user_id'] == myUid
                  ? AppColors.gold : AppColors.text, fontSize: 13,
                  fontWeight: p['user_id'] == myUid ? FontWeight.w800 : FontWeight.w400)),
          trailing: Text(_fmt(p['best_lap_ms']),
              style: const TextStyle(color: AppColors.cyan, fontSize: 12,
                  fontWeight: FontWeight.w700)),
        )),

        // Gráfico de vueltas con gap
        if (lapChart.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Tus vueltas vs la más rápida',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceAlt),
            ),
            child: Column(children: [
              SizedBox(height: 160, child: _lapsChart(lapChart)),
              const SizedBox(height: 8),
              ...lapChart.map((l) {
                final valid = l['valid'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 30,
                        child: Text('V${l['lap']}',
                            style: const TextStyle(color: AppColors.textDim, fontSize: 11))),
                    Expanded(child: Text(_fmt(l['time_ms']),
                        style: const TextStyle(color: AppColors.text, fontSize: 12,
                            fontWeight: FontWeight.w600))),
                    Expanded(child: Text('S1 ${_fmt(l['s1_ms'])}',
                        style: const TextStyle(color: AppColors.cyan, fontSize: 11))),
                    Expanded(child: Text('S2 ${_fmt(l['s2_ms'])}',
                        style: const TextStyle(color: AppColors.cyan, fontSize: 11))),
                    Expanded(child: Text('S3 ${_fmt(l['s3_ms'])}',
                        style: const TextStyle(color: AppColors.cyan, fontSize: 11))),
                    if (l['gap_to_fastest_ms'] != null)
                      Text('+${((l['gap_to_fastest_ms'] as num) / 1000).toStringAsFixed(2)}s',
                          style: TextStyle(color: valid ? AppColors.green : AppColors.red,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    if (!valid)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.block, color: AppColors.red, size: 14),
                      ),
                  ]),
                );
              }),
            ]),
          ),
        ],

        // Incidentes
        if (incidents.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Tus incidentes',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...incidents.map((i) => ListTile(
            dense: true,
            leading: const Icon(Icons.warning_amber, color: AppColors.red, size: 18),
            title: Text('${i['time']} · tipo ${i['type']}',
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          )),
        ],
      ],
    );
  }

  Widget _lapsChart(List<Map> lapChart) {
    final spots = <FlSpot>[];
    for (int i = 0; i < lapChart.length; i++) {
      final g = lapChart[i]['gap_to_fastest_ms'];
      if (g != null) {
        spots.add(FlSpot((i + 1).toDouble(), (g as num).toDouble() / 1000.0));
      }
    }
    if (spots.isEmpty) return const SizedBox.shrink();
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, meta) => Text('${v.toStringAsFixed(1)}s',
                style: TextStyle(color: AppColors.textDim, fontSize: 9)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, meta) => Text('V${v.toInt()}',
                style: TextStyle(color: AppColors.textDim, fontSize: 9)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: AppColors.gold,
          barWidth: 2.5,
          isCurved: true,
          dotData: FlDotData(show: true,
              getDotPainter: (s, p, bar, i) => FlDotCirclePainter(
                  radius: 3, color: AppColors.gold,
                  strokeWidth: 0)),
          belowBarData: BarAreaData(show: true,
              color: AppColors.gold.withValues(alpha: 0.1)),
        ),
      ],
    ));
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
