import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Detalle de una carrera: QUÉ PASÓ (historia) + datos técnicos.
class RaceDetailScreen extends StatefulWidget {
  final int profileId;
  final int raceId;
  const RaceDetailScreen({super.key, required this.profileId, required this.raceId});
  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _story;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/api/profile/${widget.profileId}/races/${widget.raceId}'),
        ApiClient.get('/api/profile/${widget.profileId}/races/${widget.raceId}/story'),
      ]);
      setState(() {
        _data = Map<String, dynamic>.from(results[0] as Map);
        _story = Map<String, dynamic>.from(results[1] as Map);
        _loading = false;
      });
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
              : DefaultTabController(
                  length: 2,
                  child: Column(children: [
                    Container(
                      color: AppColors.surface,
                      child: const TabBar(
                        tabs: [
                          Tab(text: 'Qué pasó'),
                          Tab(text: 'Datos'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(children: [
                        _storyView(),
                        _dataView(),
                      ]),
                    ),
                  ]),
                ),
    );
  }

  // ===================================================================
  // PESTAÑA 1 — QUÉ PASÓ (narrativa)
  // ===================================================================
  Widget _storyView() {
    final st = _story!;
    final race = (st['race'] as Map? ?? {});
    final summary = (st['summary'] as Map? ?? {});
    final incidents = (st['incidents'] as List? ?? []);
    final ahead = (st['ahead'] as List? ?? []);
    final posEvents = (st['position_events'] as List? ?? []);
    final gained = (summary['positions_gained'] as num?)?.toInt() ?? 0;
    final startPos = race['start_pos'];
    final finishPos = race['finish_pos'];

    final Color verdictColor = gained >= 0 ? AppColors.green : AppColors.red;
    final String verdictEmoji = gained >= 0 ? '📈' : '📉';
    final String pluralPos = (gained.abs() == 1) ? 'posición' : 'posiciones';
    final String verdictText = gained == 0
        ? 'Mantuviste tu posición'
        : gained > 0
            ? 'Ganaste $gained $pluralPos (P$startPos → P$finishPos)'
            : 'Perdiste ${-gained} $pluralPos (P$startPos → P$finishPos)';

    final laps = (st['laps'] as List? ?? []).cast<Map>();
    // mejor vuelta válida para mostrar el gap de cada vuelta
    num? bestValidMs;
    for (final l in laps) {
      if (l['valid'] == true && l['time_ms'] != null) {
        final t = l['time_ms'] as num;
        if (bestValidMs == null || t < bestValidMs) bestValidMs = t;
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Resumen narrativo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [verdictColor.withValues(alpha: 0.20), AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: verdictColor.withValues(alpha: 0.6)),
            ),
            child: Row(children: [
              Text(verdictEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${race['track_name']}',
                      style: const TextStyle(color: AppColors.text, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  Text('${race['event_name']}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(verdictText,
                      style: TextStyle(color: verdictColor, fontSize: 14, fontWeight: FontWeight.w800)),
                  Text(
                      '${summary['total_incidents'] ?? 0} ${(summary['total_incidents'] ?? 0) == 1 ? 'incidente' : 'incidentes'} · '
                      '${summary['final_lap'] ?? '—'} ${(summary['final_lap'] ?? 0) == 1 ? 'vuelta' : 'vueltas'}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Incidentes explicados
          if (incidents.isNotEmpty) ...[
            const Text('Tus incidentes, explicados',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            ...incidents.map<Widget>((raw) {
              final i = Map<String, dynamic>.from(raw as Map);
              final lap = i['lap'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i['icon'] ?? '⚠️'}', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Vuelta $lap · ${i['type_label'] ?? i['type']}',
                          style: const TextStyle(color: AppColors.red, fontSize: 13,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${i['explanation'] ?? ''}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.3)),
                    ]),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Cambios de posición
          if (posEvents.isNotEmpty) ...[
            const Text('Cómo fue tu carrera',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceAlt),
              ),
              child: Column(children: [
                for (final e in posEvents.cast<Map>().take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Text('V${e['lap']}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                          ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (e['delta'] as num) > 0
                              ? '⬆️ Subiste de P${e['from_pos']} a P${e['to_pos']}'
                              : '⬇️ Bajaste de P${e['from_pos']} a P${e['to_pos']}',
                          style: TextStyle(
                              color: (e['delta'] as num) > 0 ? AppColors.green : AppColors.red,
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ],

          // Vuelta a vuelta (análisis detallado)
          if (laps.isNotEmpty) ...[
            const Text('Tus vueltas, una a una',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Toca una vuelta para ver qué pasó en ella.',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceAlt),
              ),
              child: Column(children: [
                for (final l in laps)
                  InkWell(
                    onTap: () => _showLapDetail(context, l, bestValidMs),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(children: [
                        SizedBox(
                          width: 34,
                          child: Text('V${l['lap']}',
                              style: const TextStyle(color: AppColors.textDim, fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: Text(
                            l['valid'] == true ? _fmt(l['time_ms']) : '${_fmt(l['time_ms'])} ✂️',
                            style: TextStyle(
                                color: l['valid'] == true ? AppColors.text : AppColors.red,
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (l['position'] != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('P${l['position']}',
                                style: const TextStyle(color: AppColors.cyan, fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        if (bestValidMs != null && l['time_ms'] != null &&
                            l['valid'] == true)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                                '+${(((l['time_ms'] as num) - bestValidMs) / 1000).toStringAsFixed(2)}s',
                                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                          ),
                        if ((l['incidents'] as List? ?? []).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text('${(l['incidents'] as List).length}⚠️',
                                style: const TextStyle(color: AppColors.red, fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                        const Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
                      ]),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ],

          // Qué hacen los mejores
          if (ahead.isNotEmpty) ...[
            const Text('¿Qué hacen los que van delante?',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            ...ahead.map<Widget>((raw) {
              final a = Map<String, dynamic>.from(raw as Map);
              final tone = a['tone']?.toString() ?? 'cyan';
              final Color c = tone == 'green' ? AppColors.green
                  : tone == 'red' ? AppColors.red : AppColors.cyan;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.withValues(alpha: 0.4)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(tone == 'green' ? Icons.thumb_up_alt_rounded : Icons.psychology_alt_outlined,
                      color: c, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['title'] ?? ''}',
                          style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${a['msg'] ?? ''}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.3)),
                    ]),
                  ),
                ]),
              );
            }),
          ],

          if (incidents.isEmpty && ahead.isEmpty && posEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Sin datos de vueltas detalladas para esta carrera.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim)),
            ),
        ],
      ),
    );
  }

  // ===================================================================
  // PESTAÑA 2 — DATOS (técnicos)
  // ===================================================================
  Widget _dataView() {
    final race = Map<String, dynamic>.from(_data!['race'] as Map);
    final pilots = (_data!['pilots'] as List? ?? []).cast<Map>();
    final lapChart = (_data!['lap_chart'] as List? ?? []).cast<Map>();
    final myUid = _data!['my_user_id'];
    final dateStr = race['race_date']?.toString();
    final dateShort = fmtDate(dateStr);

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
            Row(children: [
              if (race['car_logo'] != null) ...[
                Container(
                  width: 64, height: 64,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceAlt),
                  ),
                  child: Image.network(race['car_logo'] as String,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(Icons.directions_car,
                          color: AppColors.textDim, size: 32)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text('${race['track_name']}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.text)),
              ),
            ]),
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
        ...pilots.take(10).toList().asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final isMe = p['user_id'] == myUid;
          final leaderMs = (pilots.isNotEmpty && pilots.first['best_lap_ms'] != null)
              ? (pilots.first['best_lap_ms'] as num).toDouble()
              : null;
          final myMs = (p['best_lap_ms'] as num?)?.toDouble();
          final gapMs = (myMs != null && leaderMs != null) ? myMs - leaderMs : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isMe ? AppColors.gold : AppColors.surfaceAlt,
                width: isMe ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              // Posición
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.gold.withValues(alpha: 0.18)
                      : (i == 0 ? AppColors.gold.withValues(alpha: 0.12) : AppColors.surfaceAlt),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isMe ? '★' : '${i + 1}',
                  style: TextStyle(
                    color: isMe ? AppColors.gold : (i == 0 ? AppColors.gold : AppColors.textDim),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Nombre + nº vueltas
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe ? AppColors.gold : AppColors.text,
                        fontSize: 13,
                        fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text('${p['laps']} vueltas · media ${_fmt(p['avg_lap_ms'])}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 8),
              // Tiempo + gap
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmt(p['best_lap_ms']),
                    style: const TextStyle(color: AppColors.cyan, fontSize: 13,
                        fontWeight: FontWeight.w700)),
                if (gapMs != null && gapMs > 0)
                  Text('+${_fmt(gapMs)}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
              ]),
            ]),
          );
        }),

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

  /// Bottom sheet: detalle completo de una vuelta concreta.
  void _showLapDetail(BuildContext context, Map lap, num? bestValidMs) {
    final lapNum = lap['lap'];
    final valid = lap['valid'] == true;
    final timeMs = lap['time_ms'];
    final gap = (bestValidMs != null && timeMs != null && valid)
        ? ((timeMs as num) - bestValidMs) / 1000.0 : null;
    final incs = (lap['incidents'] as List? ?? []).cast<Map>();
    final s1 = lap['s1_ms'], s2 = lap['s2_ms'], s3 = lap['s3_ms'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDim.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Text('Vuelta $lapNum',
                  style: const TextStyle(color: AppColors.text, fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              if (lap['position'] != null)
                _chip('P${lap['position']}', AppColors.cyan),
              const SizedBox(width: 6),
              _chip(valid ? 'Válida' : 'No contó', valid ? AppColors.green : AppColors.red),
            ]),
            const SizedBox(height: 16),
            // Tiempo total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tiempo de vuelta',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(valid ? _fmt(timeMs) : '${_fmt(timeMs)} (no contó)',
                        style: TextStyle(
                            color: valid ? AppColors.text : AppColors.red,
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    if (gap != null)
                      Text('+${gap.toStringAsFixed(2)}s vs tu mejor',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                  ]),
                ),
                if (valid)
                  Icon(Icons.check_circle, color: AppColors.green, size: 34)
                else
                  Icon(Icons.block, color: AppColors.red, size: 34),
              ]),
            ),
            const SizedBox(height: 14),
            // Splits
            const Text('Sectores',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Row(children: [
              _splitBox('S1', s1),
              const SizedBox(width: 8),
              _splitBox('S2', s2),
              const SizedBox(width: 8),
              _splitBox('S3', s3),
            ]),
            const SizedBox(height: 14),
            // Incidentes de esta vuelta
            if (incs.isNotEmpty) ...[
              const Text('Qué pasó en esta vuelta',
                  style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              ...incs.map((i) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i['icon'] ?? '⚠️'}', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i['type_label'] ?? i['type']}',
                          style: const TextStyle(color: AppColors.red, fontSize: 13,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${i['explanation'] ?? ''}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.3)),
                    ]),
                  ),
                ]),
              )),
            ] else ...[
              const Text('Qué pasó en esta vuelta',
                  style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
              const Text('Sin incidentes. Vuelta limpia.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12)),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _splitBox(String label, dynamic ms) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          const SizedBox(height: 4),
          Text(_fmt(ms),
              style: const TextStyle(color: AppColors.cyan, fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
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
