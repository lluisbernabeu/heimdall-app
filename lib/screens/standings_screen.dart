import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Clasificación — leaderboard de la división del piloto en cada serie.
/// Datos cacheados en BD (regla nº1): el sync guarda los standings completos
/// de cada evento y aquí se construye la vista: posición del usuario,
/// vecinos, top 10 y cuánto falta para subir.
class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});
  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  List<Map> _events = [];
  Map? _data;
  bool _loading = true;
  String? _error;
  int? _selectedEvent;
  int? _profileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final me = await ApiClient.get('/api/me');
      final pid = ((me['profiles'] as List).first as Map)['id'] as int;
      _profileId = pid;
      final d = await ApiClient.get('/api/profile/$pid/standings');
      final events = ((d['events'] as List?) ?? []).cast<Map>();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
      if (events.isNotEmpty) {
        await _select(events.first['event_id'] as int);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _select(int eventId) async {
    final pid = _profileId;
    if (pid == null) return;
    setState(() { _selectedEvent = eventId; _data = null; _loading = true; });
    try {
      final d = await ApiClient.get('/api/profile/$pid/standings/$eventId');
      if (!mounted) return;
      setState(() { _data = Map<String, dynamic>.from(d as Map); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clasificación')),
      body: _loading && _data == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null && _data == null
              ? _ErrorView(msg: _error!, onRetry: _load)
              : _body(),
    );
  }

  Widget _body() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Selector de serie
          if (_events.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  for (final e in _events)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _chip(
                        label: '${e['event_name'] ?? 'Serie'}',
                        selected: _selectedEvent == e['event_id'],
                        onTap: () => _select(e['event_id'] as int),
                      ),
                    ),
                ],
              ),
            ),
          if (_data != null) _standingsCard(_data!),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.gold : AppColors.surfaceAlt),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.goldLight : AppColors.textDim,
                fontSize: 11.5, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _standingsCard(Map d) {
    final carClass = d['car_class']?.toString() ?? 'Serie';
    final division = d['division']?.toString() ?? '—';
    final total = d['total'] as num? ?? 0;
    final myPos = d['my_position'] as num?;
    final my = (d['my_entry'] as Map?) ?? {};
    final ahead = ((d['ahead'] as List?) ?? []).cast<Map>();
    final behind = ((d['behind'] as List?) ?? []).cast<Map>();
    final top = ((d['top'] as List?) ?? []).cast<Map>();
    final nextUp = (d['next_up'] as Map?) ?? {};

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Cabecera: clase + división + tu posición
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppColors.surfaceAlt, AppColors.bg],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(carClass,
                  style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
            ),
            _Badge(text: 'División $division', color: AppColors.gold),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            // Posición grande
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(myPos != null ? '$myPosº' : '—',
                  style: const TextStyle(color: AppColors.goldLight, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(height: 4),
              Text('de $total pilotos', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            ]),
            const Spacer(),
            // Puntos
            if (my['points'] != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('PUNTOS', style: TextStyle(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text('${my['points']}',
                    style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
          ]),
          // Próximo a superar
          if (nextUp.isNotEmpty && (nextUp['gap_points'] as num? ?? 0) > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.trending_up_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('A ${(nextUp['gap_points'] as num?)?.toStringAsFixed(0)} pts de ${nextUp['name'] ?? '—'}',
                      style: const TextStyle(color: AppColors.goldLight, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
        ]),
      ),

      // Top 10
      if (top.isNotEmpty) ...[
        _sectionTitle('TOP 10'),
        for (final e in top) _row(e, isMe: e['user_id'] == my['user_id']),
      ],

      // Vecinos (los que tienes cerca, si no estás en el top)
      if (myPos != null && myPos > 10 && ahead.isNotEmpty) ...[
        const SizedBox(height: 6),
        _sectionTitle('POR DELANTE'),
        for (final e in ahead) _row(e, isMe: false),
      ],
      if (myPos != null && myPos > 10) ...[
        const SizedBox(height: 6),
        _sectionTitle('TÚ — $myPosº'),
        _row(my, isMe: true, highlight: true),
      ],
      if (myPos != null && myPos > 10 && behind.isNotEmpty) ...[
        const SizedBox(height: 6),
        _sectionTitle('POR DETRÁS'),
        for (final e in behind) _row(e, isMe: false),
      ],
    ]);
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(t,
          style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }

  Widget _row(Map e, {required bool isMe, bool highlight = false}) {
    final pos = e['position'] as num?;
    final name = e['name']?.toString() ?? '—';
    final origin = e['origin']?.toString() ?? '';
    final pts = e['points'] as num?;
    final races = e['races'] as num?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.gold.withValues(alpha: 0.14)
            : isMe ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlight ? AppColors.gold : AppColors.surfaceAlt,
            width: highlight ? 1.3 : 1),
      ),
      child: Row(children: [
        SizedBox(
          width: 38,
          child: Text(pos != null ? '$posº' : '—',
              style: TextStyle(
                  color: pos == 1 ? AppColors.goldLight
                      : pos == 2 ? AppColors.text
                      : pos == 3 ? AppColors.textDim : AppColors.textDim,
                  fontSize: 14, fontWeight: FontWeight.w900)),
        ),
        Expanded(
          child: Text(name,
              style: TextStyle(
                  color: highlight ? AppColors.goldLight : AppColors.text,
                  fontSize: 13.5,
                  fontWeight: highlight ? FontWeight.w900 : FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (origin.isNotEmpty)
          Text(origin, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        const SizedBox(width: 10),
        if (races != null)
          Text('$races carreras', style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
        const SizedBox(width: 10),
        if (pts != null)
          Text('${pts.toStringAsFixed(0)} pts',
              style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_busy_rounded, color: AppColors.red, size: 42),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      ),
    );
  }
}
