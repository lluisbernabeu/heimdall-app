import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'race_detail_screen.dart';

/// INICIO — tablero de KPIs del piloto.
///
/// Cada tarjeta es una métrica grande y clara (mejor vuelta, mejor posición,
/// incidentes, mejor sector…) y al tocarla te lleva a la pantalla que la
/// explica. La home ES el dato; la navegación nace del contenido.
class HomeDashboardScreen extends StatefulWidget {
  final int profileId;
  final Map<String, dynamic> data; // /overview
  final Map<String, dynamic>? insight; // /insight
  final void Function(int tab) onGoToTab;
  const HomeDashboardScreen({
    super.key,
    required this.profileId,
    required this.data,
    required this.insight,
    required this.onGoToTab,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<Map<String, dynamic>> _nextRaces = [];
  List<Map<String, dynamic>> _progression = [];
  List<Map<String, dynamic>> _sectors = [];
  Map<String, dynamic>? _percentile;
  bool _loading = true;
  Timer? _timer;
  DateTime? _nextRaceAt;

  @override
  void initState() {
    super.initState();
    _load();
    // Cuenta atrás viva: refresca el texto cada 30s
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pid = widget.profileId;
      final results = await Future.wait([
        ApiClient.get('/api/schedule?profile_id=$pid'),
        ApiClient.get('/api/profile/$pid/progression'),
        ApiClient.get('/api/global/sr-percentile/$pid'),
        ApiClient.get('/api/profile/$pid/sectors'),
      ]);
      if (!mounted) return;
      final schedule = (results[0] as Map)['series'] as List? ?? [];
      final prog = results[1] as List;
      final sectors = results[3] as List;
      setState(() {
        _nextRaces = [
          for (final s in schedule)
            if (s is Map && s['next_race_ms'] != null)
              Map<String, dynamic>.from(s)
        ]..sort((a, b) {
          // Prioridad: mi serie → puedo correr → más próxima
          final aMy = a['my_series'] == true ? 0 : 1;
          final bMy = b['my_series'] == true ? 0 : 1;
          if (aMy != bMy) return aMy - bMy;
          final aCan = a['can_race'] == true ? 0 : 1;
          final bCan = b['can_race'] == true ? 0 : 1;
          if (aCan != bCan) return aCan - bCan;
          return (a['next_race_ms'] as num).compareTo(b['next_race_ms'] as num);
        });
        _progression = [for (final p in prog) Map<String, dynamic>.from(p as Map)];
        _sectors = [for (final s in sectors) Map<String, dynamic>.from(s as Map)];
        _percentile = Map<String, dynamic>.from(results[2] as Map);
        _loading = false;
      });
      final nxt = _nextRaces.isNotEmpty ? _nextRaces.first['next_race_ms'] : null;
      if (nxt != null) {
        _nextRaceAt = DateTime.now().add(Duration(milliseconds: (nxt as num).toInt()));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Map<String, dynamic>.from(widget.data['profile'] as Map? ?? {});
    final s = Map<String, dynamic>.from(widget.data['stats'] as Map? ?? {});
    final insights = (widget.insight?['insights'] as List? ?? []);
    final lastRaces = (widget.data['last_races'] as List? ?? []);
    final name = (widget.insight?['profile_name']?.toString() ?? 'Piloto');
    final lic = p['ac_license']?.toString() ?? p['license']?.toString() ?? '';
    final div = (p['ac_division'] ?? p['division']) as int?;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHeader(p, s, name, lic, div),
          const SizedBox(height: 12),

          // ---- Próxima carrera (KPI rey, con cuenta atrás) ----
          if (!_loading && _nextRaceAt != null)
            _NextRaceCard(
              race: _nextRaces.first,
              countdown: _nextRaceAt!,
              onTap: () => widget.onGoToTab(1),
            )
          else if (!_loading)
            const _NoRaceCard(),

          const SizedBox(height: 16),

          // ---- Tablero de KPIs: cada métrica es una puerta ----
          const _SectionTitle('Tus números'),
          const SizedBox(height: 4),
          const Text('Toca cualquier métrica para ver su historia.',
              style: TextStyle(color: AppColors.textDim, fontSize: 11.5)),
          const SizedBox(height: 10),
          _KpiBoard(
            stats: s,
            profile: p,
            progression: _progression,
            sectors: _sectors,
            percentile: _percentile,
            onProgression: () => _push('/analysis/progression'),
            onCircuit: () => _push('/analysis/circuit'),
            onSectors: () => _push('/analysis/sectors'),
            onIncidents: () => _push('/analysis/incidents'),
            onStandings: () => _push('/profile/standings'),
            onRaces: () => widget.onGoToTab(2),
          ),

          // ---- Para ti (insights accionables) ----
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Para ti'),
            const SizedBox(height: 4),
            const Text('Basado en tus últimas carreras.',
                style: TextStyle(color: AppColors.textDim, fontSize: 11.5)),
            const SizedBox(height: 10),
            for (final raw in insights)
              _InsightCard(
                insight: Map<String, dynamic>.from(raw as Map),
                onTap: _insightRoute,
              ),
          ],

          // ---- Última carrera ----
          if (lastRaces.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Última carrera'),
            const SizedBox(height: 10),
            _LastRaceCard(
              race: Map<String, dynamic>.from(lastRaces.first as Map),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RaceDetailScreen(
                      profileId: widget.profileId,
                      raceId: (lastRaces.first as Map)['race_id'] as int))),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _insightRoute(Map<String, dynamic> i) {
    final icon = i['icon']?.toString() ?? '';
    if (icon == 'sector') {
      _push('/analysis/sectors');
    } else if (icon == 'warning' || icon == 'shield') {
      _push('/analysis/incidents');
    } else if (icon == 'trophy') {
      widget.onGoToTab(2);
    } else {
      _push('/analysis/progression');
    }
  }

  void _push(String route) {
    Navigator.of(context).pushNamed(route);
  }

  Widget _buildHeader(Map<String, dynamic> p, Map<String, dynamic> s,
      String name, String lic, int? div) {
    final avatar = p['avatar']?.toString();
    final licChip = lic.isNotEmpty ? lic : 'Sin licencia';
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: avatar != null && avatar.isNotEmpty
            ? Image.network(avatar, width: 52, height: 52,
                fit: BoxFit.cover, errorBuilder: (_, _, _) => const _AvatarFallback())
            : const _AvatarFallback(),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Row(children: [
            _HeaderChip(text: licChip, color: AppColors.gold),
            if (div != null) ...[
              const SizedBox(width: 6),
              _HeaderChip(text: 'Div $div', color: AppColors.cyan),
            ],
          ]),
        ]),
      ),
    ]);
  }
}

// =====================================================================
// Cabecera de piloto
// =====================================================================
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlt, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.gold, size: 28),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String text; final Color color;
  const _HeaderChip({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900));
  }
}

// =====================================================================
// Próxima carrera con cuenta atrás
// =====================================================================
class _NextRaceCard extends StatelessWidget {
  final Map<String, dynamic> race;
  final DateTime countdown;
  final VoidCallback onTap;
  const _NextRaceCard({required this.race, required this.countdown, required this.onTap});

  String _fmt(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return '¡En marcha!';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    if (d > 0) return '$d d · $h h';
    if (h > 0) return '$h h · $m min';
    return '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final series = race['series_name']?.toString() ?? 'Serie';
    final track = race['active_track']?.toString() ?? 'Circuito';
    final can = race['can_race'];
    final mySeries = race['my_series'];
    final thumb = race['thumbnail']?.toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.surfaceAlt, AppColors.bg],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumb != null && thumb.isNotEmpty
                  ? Image.network(thumb, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 64, height: 64,
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.flag_rounded, color: AppColors.gold, size: 28)))
                  : Container(
                      width: 64, height: 64,
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(Icons.flag_rounded, color: AppColors.gold, size: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PRÓXIMA CARRERA',
                    style: TextStyle(color: AppColors.gold, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Text(track,
                    style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 1),
                Text(series,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11.5), maxLines: 1),
                const SizedBox(height: 6),
                Row(children: [
                  if (can == true)
                    const _OkPill(text: 'Puedes correr', color: AppColors.green)
                  else if (can == false)
                    const _OkPill(text: 'Sin licencia aún', color: AppColors.gold)
                  else if (mySeries == true)
                    const _OkPill(text: 'Tu serie', color: AppColors.green),
                  const Spacer(),
                  Text(_fmt(countdown),
                      style: const TextStyle(color: AppColors.goldLight, fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OkPill extends StatelessWidget {
  final String text; final Color color;
  const _OkPill({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _NoRaceCard extends StatelessWidget {
  const _NoRaceCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Row(children: [
        const Icon(Icons.event_busy_rounded, color: AppColors.textDim, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text('No hay próximas carreras publicadas aún.',
              style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
        ),
        TextButton(
            onPressed: () {}, // reemplazado por navegación externa
            child: const Text('Calendario')),
      ]),
    );
  }
}

// =====================================================================
// TABLERO DE KPIs — 8 métricas, cada una navega a su pantalla
// =====================================================================
class _KpiBoard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> progression;
  final List<Map<String, dynamic>> sectors;
  final Map<String, dynamic>? percentile;
  final VoidCallback onProgression;
  final VoidCallback onCircuit;
  final VoidCallback onSectors;
  final VoidCallback onIncidents;
  final VoidCallback onStandings;
  final VoidCallback onRaces;
  const _KpiBoard({
    required this.stats, required this.profile, required this.progression,
    required this.sectors, required this.percentile,
    required this.onProgression, required this.onCircuit, required this.onSectors,
    required this.onIncidents, required this.onStandings, required this.onRaces,
  });

  List<FlSpot> _series(String key) {
    return [
      for (var i = 0; i < progression.length; i++)
        FlSpot(i.toDouble(), (progression[i][key] as num).toDouble()),
    ];
  }

  /// El sector más fuerte de la última carrera analizada (menor gap).
  (String, String, Color)? _bestSector() {
    if (sectors.isEmpty) return null;
    final r = sectors.first;
    final gaps = <String, num?>{
      'S1': r['gap_s1_ms'] as num?,
      'S2': r['gap_s2_ms'] as num?,
      'S3': r['gap_s3_ms'] as num?,
    };
    final valid = gaps.entries.where((e) => e.value != null).toList();
    if (valid.isEmpty) return null;
    final best = valid.reduce((a, b) => a.value! <= b.value! ? a : b);
    final ms = (best.value as num).toDouble();
    final isPositive = ms < 0; // gap negativo = mejor que el récord del split
    return (
      '${best.key} ${isPositive ? '' : '+'}${(ms / 1000).toStringAsFixed(2)}s',
      'vs el más rápido del split',
      ms < 300 ? AppColors.green : AppColors.gold,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rt = (stats['rating_trend_5'] as num?)?.toDouble();
    final st = (stats['sr_trend_5'] as num?)?.toDouble();
    final rating = profile['ac_rating'] ?? profile['c_rating'];
    final sr = profile['safety_rating'];
    final podiums = stats['podiums'] ?? 0;
    final podiumRate = stats['podium_rate'];
    final bestLap = stats['best_lap_fmt']?.toString();
    final bestLapTrack = stats['best_lap_track']?.toString();
    final bestFinish = stats['best_finish'];
    final bestFinishTrack = _bestFinishTrack();
    final avgInc = (stats['avg_incidents'] as num?)?.toDouble();
    final betterThan = (percentile?['percentile'] as Map?)?['better_than_pct'];
    final bs = _bestSector();

    return Column(children: [
      Row(children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.speed_rounded,
            iconColor: AppColors.gold,
            label: 'Rating',
            value: rating?.toString() ?? '—',
            sub: _trendText(rt, 'pts'),
            trendUp: rt == null ? null : rt >= 0,
            spark: _series('rating'),
            sparkColor: rt != null && rt < 0 ? AppColors.red : AppColors.green,
            onTap: onProgression,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            icon: Icons.verified_user_rounded,
            iconColor: AppColors.green,
            label: 'SR',
            value: sr?.toStringAsFixed(2) ?? '—',
            sub: _trendText(st, 'SR'),
            trendUp: st == null ? null : st >= 0,
            spark: _series('sr'),
            sparkColor: st != null && st < 0 ? AppColors.red : AppColors.green,
            onTap: onProgression,
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.timer_rounded,
            iconColor: AppColors.cyan,
            label: 'Mejor vuelta',
            value: bestLap ?? '—',
            sub: bestLapTrack ?? 'en todas tus carreras',
            onTap: onCircuit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            icon: Icons.emoji_events_rounded,
            iconColor: AppColors.goldLight,
            label: 'Mejor posición',
            value: bestFinish != null ? 'P$bestFinish' : '—',
            sub: bestFinishTrack ?? 'en carrera',
            onTap: onRaces,
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.report_rounded,
            iconColor: avgInc != null && avgInc > 6 ? AppColors.red : AppColors.green,
            label: 'Incidentes',
            value: avgInc?.toStringAsFixed(1) ?? '—',
            sub: 'de media por carrera',
            onTap: onIncidents,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: bs == null
              ? const SizedBox.shrink()
              : _KpiCard(
                  icon: Icons.timer_outlined,
                  iconColor: bs.$3,
                  label: 'Mejor sector',
                  value: bs.$1,
                  sub: bs.$2,
                  onTap: onSectors,
                ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.public_rounded,
            iconColor: AppColors.cyan,
            label: 'Comunidad',
            value: betterThan != null ? '${(betterThan as num).toStringAsFixed(1)}%' : '—',
            sub: 'mejor que en SR',
            onTap: onStandings,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            icon: Icons.flag_rounded,
            iconColor: AppColors.gold,
            label: 'Podios',
            value: '$podiums',
            sub: podiumRate != null ? '$podiumRate% de tus carreras' : 'en tus carreras',
            onTap: onRaces,
          ),
        ),
      ]),
    ]);
  }

  String? _bestFinishTrack() {
    final bf = stats['best_finish'];
    if (bf == null) return null;
    for (final r in progression) {
      if (r['finish_pos'] == bf) return r['track']?.toString();
    }
    return null;
  }

  String _trendText(double? v, String unit) {
    if (v == null) return 'estable';
    final s = v >= 0 ? '+' : '';
    return '$s${v.toStringAsFixed(v.abs() < 10 ? 2 : 0)} $unit';
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? sub;
  final bool? trendUp;
  final List<FlSpot>? spark;
  final Color? sparkColor;
  final VoidCallback onTap;
  const _KpiCard({
    required this.icon, required this.iconColor, required this.label,
    required this.value, this.sub, this.trendUp, this.spark, this.sparkColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceAlt),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: iconColor, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label.toUpperCase(),
                    style: const TextStyle(color: AppColors.textDim, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 0.7),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (trendUp != null)
                Icon(trendUp! ? Icons.arrow_upward : Icons.arrow_downward,
                    color: trendUp! ? AppColors.green : AppColors.red, size: 14),
            ]),
            const Spacer(),
            Text(value,
                style: const TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w900),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null)
              Text(sub!,
                  style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            if (spark != null && spark!.length > 1)
              SizedBox(
                height: 24,
                child: LineChart(LineChartData(
                  minX: 0,
                  maxX: (spark!.length - 1).toDouble(),
                  minY: spark!.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 1,
                  maxY: spark!.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 1,
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spark!,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: sparkColor ?? AppColors.gold,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: (sparkColor ?? AppColors.gold).withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                )),
              ),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================
// Insight accionable — el contenido te lleva a la herramienta
// =====================================================================
class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  final void Function(Map<String, dynamic>) onTap;
  const _InsightCard({required this.insight, required this.onTap});

  Color _tone(String t) {
    switch (t) {
      case 'red': return AppColors.red;
      case 'green': return AppColors.green;
      case 'orange': return AppColors.gold;
      default: return AppColors.cyan;
    }
  }

  IconData _icon(String i) {
    switch (i) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'shield': return Icons.verified_user_rounded;
      case 'sector': return Icons.timer_outlined;
      case 'trophy': return Icons.emoji_events_rounded;
      default: return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _tone(insight['tone']?.toString() ?? 'cyan');
    return InkWell(
      onTap: () => onTap(insight),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_icon(insight['icon']?.toString() ?? ''), color: c, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(insight['title']?.toString() ?? '',
                  style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(insight['msg']?.toString() ?? '',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11.5, height: 1.35)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textDim, size: 19),
        ]),
      ),
    );
  }
}

// =====================================================================
// Última carrera — resultado real con acceso al detalle
// =====================================================================
class _LastRaceCard extends StatelessWidget {
  final Map<String, dynamic> race;
  final VoidCallback onTap;
  const _LastRaceCard({required this.race, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pos = race['finish_pos'];
    final track = race['track_name']?.toString() ?? '?';
    final event = race['event_name']?.toString() ?? '';
    final rc = race['rating_change'];
    final sc = race['sr_change'];
    final inc = race['incidents'];
    final rcNum = rc as num?;
    final scNum = sc as num?;
    final incNum = inc as num?;
    final bow = race['best_of_week'] == true;
    final carLogo = race['car_logo']?.toString();
    final p1 = pos == 1;
    final podium = pos != null && pos <= 3;
    final color = p1 ? AppColors.goldLight : (podium ? AppColors.gold : AppColors.text);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.surfaceAlt, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            if (carLogo != null && carLogo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(carLogo, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _CarFallback()),
              )
            else
              const _CarFallback(),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('P$pos',
                      style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900)),
                  if (bow) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, color: AppColors.goldLight, size: 18),
                  ],
                  const Spacer(),
                  if (rcNum != null)
                    Text('${rcNum >= 0 ? '+' : ''}${rcNum.toStringAsFixed(0)} rating',
                        style: TextStyle(
                            color: rcNum >= 0 ? AppColors.green : AppColors.red,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 2),
                Text(track,
                    style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(event,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11), maxLines: 1),
                const SizedBox(height: 5),
                Row(children: [
                  if (incNum != null)
                    _MiniStat(label: '$incNum inc', color: incNum > 6 ? AppColors.red : AppColors.green),
                  if (scNum != null) ...[
                    const SizedBox(width: 8),
                    _MiniStat(
                        label: 'SR ${scNum >= 0 ? '+' : ''}${scNum.toStringAsFixed(2)}',
                        color: scNum >= 0 ? AppColors.green : AppColors.red),
                  ],
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textDim, size: 22),
          ]),
        ),
      ),
    );
  }
}

class _CarFallback extends StatelessWidget {
  const _CarFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.directions_car_rounded, color: AppColors.gold, size: 24),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label; final Color color;
  const _MiniStat({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}
