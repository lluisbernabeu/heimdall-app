import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
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
  Map<String, dynamic>? _replay;
  bool _loading = true;
  String? _error;
  dynamic _highlightUid; // piloto resaltado en la gráfica (null = ninguno)

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/api/profile/${widget.profileId}/races/${widget.raceId}'),
        ApiClient.get('/api/profile/${widget.profileId}/races/${widget.raceId}/story'),
        ApiClient.get('/api/profile/${widget.profileId}/races/${widget.raceId}/replay'),
      ]);
      setState(() {
        _data = Map<String, dynamic>.from(results[0] as Map);
        _story = Map<String, dynamic>.from(results[1] as Map);
        _replay = Map<String, dynamic>.from(results[2] as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  // ===================================================================
  // PESTAÑA 3 — REPLAY (posición vuelta a vuelta + comparativa sectores)
  // ===================================================================
  Widget _replayView() {
    final rep = _replay!;
    final chart = (rep['position_chart'] as List? ?? []).cast<Map>();
    final lapPilots = (rep['lap_pilots'] as List? ?? []).cast<Map>();
    final myUid = _data!['my_user_id'];
    final vod = rep['vod_link']?.toString();
    final live = rep['live_video']?.toString();
    final videolink = rep['videolink']?.toString();
    final vods = <String>{
      if (vod != null && vod.isNotEmpty) vod,
      if (live != null && live.isNotEmpty) live,
      if (videolink != null && videolink.isNotEmpty) videolink,
    }.toList();
    final multiTwitch = (rep['multiTwitch'] as List? ?? [])
        .expand((e) => e is List ? e : [e])
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    if (chart.isEmpty && lapPilots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No hay datos de replay para esta carrera todavía.\n'
              'Pulsa sincronizar para intentar descargarlos.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enlaces de video/stream si los hay
          if (vods.isNotEmpty || multiTwitch.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📺 Esta carrera fue transmitida',
                    style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                for (final v in vods)
                  _linkButton('▶️ Ver VOD en YouTube', v, AppColors.red),
                for (final t in multiTwitch)
                  _linkButton('🔴 Stream en Twitch', 'https://www.twitch.tv/$t', AppColors.red),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // Gráfica de posiciones
          const Text('Posiciones vuelta a vuelta',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text('Dorado = tú · toca un piloto de la lista para seguir su línea.',
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          const SizedBox(height: 10),
          if (chart.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceAlt),
              ),
              child: Column(children: [
                SizedBox(height: 240, child: _positionChart(chart, myUid)),
                const SizedBox(height: 6),
                ..._chartLegend(chart, myUid),
              ]),
            ),
          const SizedBox(height: 16),

          // Comparativa de sectores
          if (lapPilots.isNotEmpty)
            _sectorComparison(lapPilots, myUid),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Gráfico de líneas: posición (invertida, P1 arriba) por vuelta.
  /// Colores estables por piloto (índice en el chart).
  /// Paleta mineral desaturada que armoniza con negro+oro. El dorado
  /// queda reservado para TÚ (goldLight) — los rivales NUNCA usan oro.
  static const List<Color> _palette = [
    Color(0xFFC8786A), Color(0xFF7EA6C4), Color(0xFF8FC48A),
    Color(0xFFC4A06A), Color(0xFFA67EC4), Color(0xFF6AB8B8),
    Color(0xFFC48A5E), Color(0xFF9AB86A), Color(0xFFC46A9E),
    Color(0xFF6A9EC4), Color(0xFFB8B86A), Color(0xFF7EC4A0),
    Color(0xFFC46A6A), Color(0xFF8A8AC4), Color(0xFFA0C46A),
    Color(0xFFC4A0B8), Color(0xFF6AC49E), Color(0xFF9E6AC4),
  ];

  Widget _positionChart(List<Map> chart, dynamic myUid) {
    // max vuelta para el eje X
    int maxLap = 1;
    for (final p in chart) {
      for (final l in (p['laps'] as List? ?? [])) {
        final lap = (l is Map ? l['lap'] : null) as num?;
        if (lap != null && lap > maxLap) maxLap = lap.toInt();
      }
    }

    final bars = <LineChartBarData>[];
    for (int i = 0; i < chart.length; i++) {
      final p = chart[i];
      final isMe = p['user_id'] == myUid;
      final isHl = p['user_id'] == _highlightUid;
      final laps = (p['laps'] as List? ?? []).cast<Map>();
      final spots = <FlSpot>[];
      for (final l in laps) {
        final lap = l['lap'] as num?;
        final pos = l['position'] as num?;
        if (lap != null && pos != null) {
          // invertir: P1 arriba
          spots.add(FlSpot(lap.toDouble(), -pos.toDouble()));
        }
      }
      if (spots.isEmpty) continue;

      // Diseño legible: TÚ dorado grueso; el resaltado en su color;
      // el resto gris tenue (o en su color suave si no hay resaltado).
      Color color;
      double width;
      if (isMe) {
        color = AppColors.goldLight;
        width = 4;
      } else if (isHl) {
        color = _palette[i % _palette.length];
        width = 3.2;
      } else if (_highlightUid == null) {
        color = _palette[i % _palette.length].withValues(alpha: 0.30);
        width = 1.6;
      } else {
        color = AppColors.textDim.withValues(alpha: 0.12);
        width = 1.2;
      }

      bars.add(LineChartBarData(
        spots: spots,
        color: color,
        barWidth: width,
        isCurved: false,
        preventCurveOverShooting: true,
        dotData: FlDotData(show: false),
      ));
    }

    // invertir eje Y: -P -> +P (P1 arriba)
    int maxPos = 1;
    for (final p in chart) {
      for (final l in (p['laps'] as List? ?? [])) {
        final pos = (l is Map ? l['position'] : null) as num?;
        if (pos != null && pos > maxPos) maxPos = pos.toInt();
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.surfaceAlt.withValues(alpha: 0.6),
            strokeWidth: 0.8,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, meta) => Text('P${(-v).round()}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: maxLap > 12 ? 2 : 1,
              getTitlesWidget: (v, meta) => Text('V${v.round()}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 9)),
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minX: 0,
        maxX: maxLap.toDouble(),
        minY: -maxPos.toDouble(),
        maxY: -1.0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceAlt,
            getTooltipItems: (touchedSpots) {
              final items = <LineTooltipItem>[];
              for (final t in touchedSpots) {
                if (t.barIndex >= chart.length) continue;
                final p = chart[t.barIndex];
                final uid = p['user_id'];
                // si hay resaltado, solo mostramos el resaltado y TÚ
                if (_highlightUid != null && uid != _highlightUid && uid != myUid) {
                  continue;
                }
                final isMe = uid == myUid;
                items.add(LineTooltipItem(
                  '${p['driver'] ?? ''}  P${(-t.y).round()}',
                  TextStyle(
                    color: isMe ? AppColors.goldLight : AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ));
              }
              return items;
            },
          ),
        ),
        lineBarsData: bars,
      ),
    );
  }

  /// Leyenda de la gráfica: tocar un piloto lo resalta en su color.
  List<Widget> _chartLegend(List<Map> chart, dynamic myUid) {
    return chart.asMap().entries.map((e) {
      final i = e.key;
      final p = e.value;
      final isMe = p['user_id'] == myUid;
      final isHl = p['user_id'] == _highlightUid;
      final laps = (p['laps'] as List? ?? []);
      final finish = laps.isNotEmpty ? (laps.last is Map ? laps.last['position'] : null) : null;

      Color color;
      if (isMe) {
        color = AppColors.goldLight;
      } else if (isHl || _highlightUid == null) {
        color = _palette[i % _palette.length];
      } else {
        color = AppColors.textDim.withValues(alpha: 0.30);
      }

      return InkWell(
        onTap: () => setState(() {
          _highlightUid = isHl ? null : p['user_id'];
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isHl
                    ? Border.all(color: AppColors.text, width: 1.2)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${p['driver'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isMe ? AppColors.goldLight : AppColors.textDim,
                      fontSize: 11,
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w500)),
            ),
            Text(finish != null ? 'P$finish' : '',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ]),
        ),
      );
    }).toList();
  }

  /// Comparativa de sectores: TÚ vs rival seleccionable (por defecto el ganador).
  Widget _sectorComparison(List<Map> lapPilots, dynamic myUid) {
    // identificar mi piloto y el rival (ganador por defecto)
    Map? me;
    for (final p in lapPilots) {
      if (p['user_id'] == myUid) { me = p; break; }
    }
    final rivals = lapPilots.where((p) => p['user_id'] != myUid).toList();
    if (me == null && rivals.isNotEmpty) {
      // si no me identifico, comparo a los dos primeros
      me = lapPilots.first;
      rivals.removeWhere((p) => p == me);
    }
    if (me == null || rivals.isEmpty) {
      return const SizedBox.shrink();
    }
    rivals.sort((a, b) => ((a['position'] as num?) ?? 999)
        .compareTo((b['position'] as num?) ?? 999));
    Map rival = rivals.first; // el que quedó mejor (ganador normalmente)

    return StatefulBuilder(
      builder: (context, setState) {
        final myLaps = (me!['laps'] as List? ?? []).cast<Map>();
        final rivLaps = (rival['laps'] as List? ?? []).cast<Map>();
        final rivByLap = {for (final l in rivLaps) (l['lap'] as num?)?.toInt(): l};

        // resumen por sector: suma de deltas (tú - rival) en vueltas válidas
        num s1 = 0, s2 = 0, s3 = 0, total = 0;
        int n = 0;
        final rows = <Map>[];
        for (final ml in myLaps) {
          final lapNum = (ml['lap'] as num?)?.toInt();
          final rl = lapNum != null ? rivByLap[lapNum] : null;
          if (rl == null) continue;
          final d1 = (ml['s1_ms'] as num?) != null && (rl['s1_ms'] as num?) != null
              ? (ml['s1_ms'] as num) - (rl['s1_ms'] as num) : null;
          final d2 = (ml['s2_ms'] as num?) != null && (rl['s2_ms'] as num?) != null
              ? (ml['s2_ms'] as num) - (rl['s2_ms'] as num) : null;
          final d3 = (ml['s3_ms'] as num?) != null && (rl['s3_ms'] as num?) != null
              ? (ml['s3_ms'] as num) - (rl['s3_ms'] as num) : null;
          final valid = ml['valid'] == true && rl['valid'] == true;
          if (!valid) continue;
          if (d1 != null) s1 += d1;
          if (d2 != null) s2 += d2;
          if (d3 != null) s3 += d3;
          final dTotal = (d1 ?? 0) + (d2 ?? 0) + (d3 ?? 0);
          total += dTotal;
          n++;
          rows.add({
            'lap': lapNum,
            'd1': d1, 'd2': d2, 'd3': d3,
            'total': dTotal,
            'myTime': ml['time_ms'], 'rivTime': rl['time_ms'],
          });
        }

        // ¿dónde le ganas?
        String where = '';
        if (n > 0) {
          final parts = <String>[];
          if (s1 < 0) parts.add('S1 le ganas ${_signed(-s1)}');
          if (s2 < 0) parts.add('S2 le ganas ${_signed(-s2)}');
          if (s3 < 0) parts.add('S3 le ganas ${_signed(-s3)}');
          final loses = <String>[];
          if (s1 > 0) loses.add('S1 pierdes ${_signed(s1)}');
          if (s2 > 0) loses.add('S2 pierdes ${_signed(s2)}');
          if (s3 > 0) loses.add('S3 pierdes ${_signed(s3)}');
          where = [if (parts.isNotEmpty) 'Ganas: ${parts.join(', ')}',
                   if (loses.isNotEmpty) 'Pierdes: ${loses.join(', ')}'].join('  ·  ');
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Comparativa por sectores',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text('Tú vs rival · verde = le ganas · rojo = pierdes.',
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          const SizedBox(height: 8),
          // selector de rival
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final r in rivals)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${r['name'] ?? ''} (P${r['position'] ?? '?'})',
                        style: const TextStyle(fontSize: 11)),
                    selected: r == rival,
                    selectedColor: AppColors.cyan.withValues(alpha: 0.25),
                    backgroundColor: AppColors.surfaceAlt,
                    labelStyle: TextStyle(
                        color: r == rival ? AppColors.cyan : AppColors.textDim,
                        fontSize: 11),
                    onSelected: (_) => setState(() => rival = r),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),

          // resumen donde ganas/pierdes
          if (where.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.35)),
              ),
              child: Text(where,
                  style: const TextStyle(color: AppColors.text, fontSize: 12, height: 1.35)),
            ),

          // tabla vuelta a vuelta
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceAlt),
            ),
            child: Column(children: [
              // cabecera
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: const [
                  SizedBox(width: 30, child: Text('V', style: TextStyle(color: AppColors.textDim, fontSize: 10))),
                  Expanded(child: Text('S1', style: TextStyle(color: AppColors.textDim, fontSize: 10))),
                  Expanded(child: Text('S2', style: TextStyle(color: AppColors.textDim, fontSize: 10))),
                  Expanded(child: Text('S3', style: TextStyle(color: AppColors.textDim, fontSize: 10))),
                  Expanded(child: Text('Total', style: TextStyle(color: AppColors.textDim, fontSize: 10))),
                ]),
              ),
              const Divider(height: 1, color: AppColors.surfaceAlt),
              for (final row in rows.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 30, child: Text('V${row['lap']}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11))),
                    Expanded(child: _deltaCell(row['d1'])),
                    Expanded(child: _deltaCell(row['d2'])),
                    Expanded(child: _deltaCell(row['d3'])),
                    Expanded(child: _deltaCell(row['total'], bold: true)),
                  ]),
                ),
              if (n > 0) ...[
                const Divider(height: 1, color: AppColors.surfaceAlt),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [
                    const SizedBox(width: 30, child: Text('Σ', style: TextStyle(color: AppColors.textDim, fontSize: 11))),
                    Expanded(child: _deltaCell(s1)),
                    Expanded(child: _deltaCell(s2)),
                    Expanded(child: _deltaCell(s3)),
                    Expanded(child: _deltaCell(total, bold: true)),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 4),
          Text('Valores en ms · (tú − rival): negativo = tú más rápido.',
              style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
        ]);
      },
    );
  }

  Widget _deltaCell(dynamic ms, {bool bold = false}) {
    final num? v = ms is num ? ms : null;
    final String label = v == null
        ? '—'
        : '${v >= 0 ? '+' : ''}${(v / 1000).toStringAsFixed(2)}';
    final Color c = v == null ? AppColors.textDim
        : v == 0 ? AppColors.textDim
        : v < 0 ? AppColors.green : AppColors.red;
    return Text(label,
        style: TextStyle(color: c, fontSize: bold ? 12 : 11,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600));
  }

  String _signed(num ms) {
    return '${(ms / 1000).toStringAsFixed(2)}s';
  }

  Widget _linkButton(String label, String url, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () async {
          try {
            final uri = Uri.parse(url);
            if (await _canLaunch(uri)) await _launch(uri);
          } catch (_) {}
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Future<bool> _canLaunch(Uri uri) async => true;
  Future<void> _launch(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _fmt(num? ms) => fmtLap(ms);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de carrera')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : DefaultTabController(
                  length: 3,
                  child: Column(children: [
                    Container(
                      color: AppColors.surface,
                      child: const TabBar(
                        tabs: [
                          Tab(text: 'Qué pasó'),
                          Tab(text: 'Datos'),
                          Tab(text: 'Replay'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(children: [
                        _storyView(),
                        _dataView(),
                        _replayView(),
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
    final noLaps = st['no_laps'] == true;
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
                  Text('${race['track_name'] ?? ''}',
                      style: const TextStyle(color: AppColors.text, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  Text('${race['event_name'] ?? ''}',
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
                                style: const TextStyle(color: AppColors.gold, fontSize: 12,
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
              final tone = a['tone']?.toString() ?? 'gold';
              final Color c = tone == 'green' ? AppColors.green
                  : tone == 'red' ? AppColors.red : AppColors.gold;
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  noLaps
                      ? 'No hay datos de vueltas descargadas para esta carrera todavía. Pulsa el botón de sincronizar para intentar descargarlas.'
                      : 'Sin datos de vueltas detalladas para esta carrera.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim)),
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
              colors: [AppColors.surfaceAlt, AppColors.bg],
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
              _chip('Split ${race['split']}', AppColors.gold),
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
                    style: const TextStyle(color: AppColors.gold, fontSize: 13,
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
                _chip('P${lap['position']}', AppColors.gold),
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
              style: const TextStyle(color: AppColors.gold, fontSize: 15,
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
