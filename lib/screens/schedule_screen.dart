import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Vista Calendario — todas las series de Assetto Corsa en LFM.
/// Diseño limpio: una señal clara por tarjeta (¿puedo correr? ¿cuándo?),
/// la semana actual destacada y acciones directas (mod / apuntarse).
class ScheduleScreen extends StatefulWidget {
  final int? profileId;
  const ScheduleScreen({super.key, this.profileId});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final Set<int> _expanded = {};
  int _filter = 0; // 0 = todas, 1 = puedo correr, 2 = mis series
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pid = widget.profileId;
      final q = pid != null ? '?profile_id=$pid' : '';
      final data = await ApiClient.get('/api/schedule$q');
      if (!mounted) return;
      setState(() { _data = Map<String, dynamic>.from(data as Map); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final days = const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    final months = const ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                          'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    String hhmm(int v) => v.toString().padLeft(2, '0');
    return '${days[local.weekday - 1]} ${local.day} ${months[local.month - 1]} '
        '${hhmm(local.hour)}:${hhmm(local.minute)}';
  }

  /// Cuenta atrás legible. Devuelve (texto, urgente).
  (String, bool) _countdown(num? ms) {
    if (ms == null) return ('—', false);
    if (ms <= 0) return ('¡YA!', true);
    final s = (ms / 1000).round();
    if (s < 60) return ('${s}s', true);
    final m = s ~/ 60;
    if (m < 60) return ('$m min', true);
    final h = m ~/ 60;
    if (h < 48) {
      final rem = m % 60;
      return (rem == 0 ? '${h}h' : '${h}h ${rem.toString().padLeft(2, '0')}m', h < 4);
    }
    return ('${h ~/ 24}d', false);
  }

  String _flag(String? iso) {
    if (iso == null || iso.length != 2) return '🏁';
    return String.fromCharCodes(iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
  }

  String _km(num? km) {
    if (km == null) return '';
    return ' · ${(km / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir $url')));
    }
  }

  /// Abre la guía de un circuito: récord LFM + videos de YouTube.
  Future<void> _showGuide(String track, String? carClass) async {
    final data = await _loadGuide(track, carClass);
    if (!mounted || data == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _GuideSheet(track: track, data: data, onOpen: _open),
    );
  }

  Future<Map<String, dynamic>?> _loadGuide(String track, String? carClass) async {
    try {
      final q = Uri(queryParameters: {
        'track': track,
        'car_class': ?carClass,
      }).query;
      final d = await ApiClient.get('/api/schedule/guide?$q');
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.event_busy_rounded, color: AppColors.red, size: 42),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.red, fontSize: 13)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Reintentar')),
                    ]),
                  ),
                )
              : _body(),
    );
  }

  Widget _body() {
    final series = ((_data?['series'] as List?) ?? []).cast<Map>();
    final season = _data?['season_name'] as String? ?? '';
    final week = _data?['season_week'];
    final myLic = _data?['my_license'] as String?;
    final mySr = _data?['my_sr'] as num?;

    final filtered = series.where((s) {
      switch (_filter) {
        case 1: return s['can_race'] == true;
        case 2: return s['my_series'] == true;
        default: return true;
      }
    }).toList();
    final canCount = series.where((s) => s['can_race'] == true).length;
    final myCount = series.where((s) => s['my_series'] == true).length;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Cabecera: temporada + tu estado
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.surfaceAlt, AppColors.bg],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              const Icon(Icons.event_available_rounded, color: AppColors.gold, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(season.isEmpty ? 'Temporada' : season,
                      style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(myLic != null
                      ? '$myLic · SR ${(mySr ?? 0).toStringAsFixed(2)} · puedes correr $canCount de ${series.length}'
                      : 'Assetto Corsa · Low Fuel Motorsport',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
                ]),
              ),
              if (week != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text('Semana $week',
                      style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          // Estado LFM en vivo (usuarios online, servidores, comunidad)
          _LfmStatusStrip(),
          // Filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              _filterChip(0, 'Todas (${series.length})'),
              const SizedBox(width: 8),
              _filterChip(1, 'Puedo correr ($canCount)'),
              const SizedBox(width: 8),
              if (myCount > 0) _filterChip(2, 'Mis series ($myCount)'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text('Series activas',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ),
          for (final s in filtered) _SeriesCard(
            s: s,
            expanded: _expanded.contains(s['event_id']),
            onToggle: () {
              setState(() {
                final id = s['event_id'] as int?;
                if (id == null) return;
                if (!_expanded.remove(id)) _expanded.add(id);
              });
            },
            fmtDate: _fmtDate,
            countdown: _countdown,
            flag: _flag,
            km: _km,
            onOpen: _open,
            onGuide: (track, carClass) => _showGuide(track, carClass),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Icon(Icons.filter_alt_off_rounded, color: AppColors.textDim, size: 36),
                const SizedBox(height: 8),
                Text(_filter == 2 ? 'No has corrido ninguna de estas series aún' : 'Sin resultados',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
              ]),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filterChip(int idx, String label) {
    final sel = _filter == idx;
    return InkWell(
      onTap: () => setState(() => _filter = idx),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.gold.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.gold : AppColors.surfaceAlt),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? AppColors.goldLight : AppColors.textDim,
                fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Tarjeta de serie. Jerarquía visual: ¿puedo correr? -> ¿cuándo? -> ¿dónde?
/// -> acciones. La semana actual del calendario expandido queda destacada.
class _SeriesCard extends StatelessWidget {
  final Map s;
  final bool expanded;
  final VoidCallback onToggle;
  final String Function(String?) fmtDate;
  final (String, bool) Function(num?) countdown;
  final String Function(String?) flag;
  final String Function(num?) km;
  final Future<void> Function(String?) onOpen;
  final Future<void> Function(String track, String? carClass) onGuide;

  const _SeriesCard({required this.s, required this.expanded,
    required this.onToggle, required this.fmtDate, required this.countdown,
    required this.flag, required this.km, required this.onOpen,
    required this.onGuide});

  @override
  Widget build(BuildContext context) {
    final name = s['series_name']?.toString() ?? 'Serie';
    final activeTrack = s['active_track']?.toString() ?? '';
    final nextDate = s['next_race_date']?.toString();
    final nxtMs = s['next_race_ms'] as num?;
    final minLic = s['min_license']?.toString() ?? '';
    final minSr = s['min_sr'];
    final raceLen = s['race_length'];
    final canRace = s['can_race'];
    final mySeries = s['my_series'] == true;
    final weeks = ((s['weeks'] as List?) ?? []).cast<Map>();
    final classes = ((s['classes'] as List?) ?? []).cast<Map>();
    final contentLink = s['content_link'] as String?;
    final signupLink = s['signup_link'] as String?;
    final carClass = classes.isNotEmpty ? classes.first['name']?.toString() : null;

    final (cdText, cdUrgent) = countdown(nxtMs);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canRace == true
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.surfaceAlt,
          width: canRace == true ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Fila principal: nombre + estado + chevron
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (mySeries) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: const Text('TU SERIE',
                            style: TextStyle(color: AppColors.goldLight, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  // Una línea discreta: duración · licencia · SR
                  Text('$raceLen min · $minLic${minSr != null ? ' · SR $minSr' : ''}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
                ]),
              ),
              // Estado: una sola señal clara
              if (canRace != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (canRace ? AppColors.green : AppColors.red).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: (canRace ? AppColors.green : AppColors.red).withValues(alpha: 0.45)),
                  ),
                  child: Text(canRace ? '✓ Puedes' : '✕ Bloqueada',
                      style: TextStyle(
                          color: canRace ? AppColors.green : AppColors.red,
                          fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textDim, size: 24),
            ]),
          ),
          // ¿Dónde? Semana actual
          if (activeTrack.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(children: [
                const Icon(Icons.place_rounded, color: AppColors.gold, size: 15),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(activeTrack,
                      style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text('ESTA SEMANA',
                      style: TextStyle(color: AppColors.goldLight, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                ),
              ]),
            ),
          // ¿Cuándo? Próxima carrera + countdown
          if (nextDate != null && nextDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(children: [
                const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 15),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(fmtDate(nextDate),
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (cdUrgent ? AppColors.green : AppColors.gold).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (cdUrgent ? AppColors.green : AppColors.gold).withValues(alpha: 0.45)),
                  ),
                  child: Text(cdText,
                      style: TextStyle(
                          color: cdUrgent ? AppColors.green : AppColors.gold,
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          // Acciones: solo las que importan
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              _actionBtn(Icons.ondemand_video_rounded, 'Guía',
                  () => onGuide(activeTrack, carClass)),
              if (signupLink != null)
                _actionBtn(Icons.login_rounded, 'Apuntarse', () => onOpen(signupLink)),
              if (contentLink != null && contentLink.isNotEmpty)
                _actionBtn(Icons.download_rounded, 'Mod', () => onOpen(contentLink)),
            ]),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.surfaceAlt),
            // Calendario semanal con la semana actual destacada
            if (weeks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Text('Calendario',
                    style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              ),
            for (final w in weeks)
              InkWell(
                onTap: () => onGuide(w['track']?.toString() ?? '', carClass),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: w['is_current'] == true
                        ? AppColors.gold.withValues(alpha: 0.13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: w['is_current'] == true
                            ? AppColors.gold.withValues(alpha: 0.5)
                            : Colors.transparent),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 34,
                      child: Text('S${(w['week_num'] as num? ?? 0).toString().padLeft(2, '0')}',
                          style: TextStyle(
                              color: w['is_current'] == true ? AppColors.goldLight : AppColors.textDim,
                              fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ),
                    Text(flag(w['country']), style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(w['track']?.toString() ?? '',
                          style: TextStyle(
                              color: w['is_current'] == true ? AppColors.text : AppColors.textDim,
                              fontSize: 12,
                              fontWeight: w['is_current'] == true ? FontWeight.w800 : FontWeight.w400),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.ondemand_video_rounded, color: AppColors.gold, size: 15),
                    const SizedBox(width: 4),
                    if (w['is_current'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text('AHORA',
                            style: TextStyle(color: AppColors.goldLight, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      )
                    else
                      Text('${w['turns'] ?? ''} c${km(w['km'])}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
                  ]),
                ),
              ),
            if (classes.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Divider(height: 1, color: AppColors.surfaceAlt),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Text('Coches',
                    style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              ),
              for (final c in classes)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                  child: Text(
                    ((c['cars'] as List?) ?? []).map((car) => car['name']?.toString() ?? '').where((x) => x.isNotEmpty).join(' · '),
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11.5),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.gold, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// Hoja de guía de un circuito: récord oficial LFM + videos de YouTube.
class _GuideSheet extends StatelessWidget {
  final String track;
  final Map<String, dynamic> data;
  final Future<void> Function(String?) onOpen;
  const _GuideSheet({required this.track, required this.data, required this.onOpen});

  String _fmtDur(num? sec) {
    if (sec == null) return '';
    final m = sec ~/ 60;
    final s = (sec % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final record = Map<String, dynamic>.from(data['record'] as Map? ?? {});
    final videos = ((data['videos'] as List?) ?? []).cast<Map>();
    final carClass = data['car_class']?.toString() ?? '';
    final q = Map<String, dynamic>.from(record['qualifying'] as Map? ?? {});
    final r = Map<String, dynamic>.from(record['race'] as Map? ?? {});

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(children: [
              const Icon(Icons.ondemand_video_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(track,
                    style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              if (carClass.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(carClass,
                      style: const TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          // Récord oficial
          if (record.isNotEmpty && (q.isNotEmpty || r.isNotEmpty)) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RÉCORD OFICIAL LFM',
                    style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                if (q.isNotEmpty)
                  _recordRow('Clasificación', q['lap']?.toString() ?? '—',
                      q['driver']?.toString() ?? '', q['date']?.toString() ?? ''),
                if (r.isNotEmpty)
                  _recordRow('Carrera', r['lap']?.toString() ?? '—',
                      r['driver']?.toString() ?? '', r['date']?.toString() ?? ''),
              ]),
            ),
          ],
          // Videos
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
            child: Text(videos.isEmpty ? 'Sin videos encontrados' : 'Guías y hotlaps en YouTube (${videos.length})',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: videos.length,
              itemBuilder: (ctx, i) {
                final v = videos[i];
                final title = v['title']?.toString() ?? '';
                final chan = v['channel']?.toString() ?? '';
                final dur = v['duration'] as num?;
                final thumb = v['thumbnail']?.toString() ?? '';
                return InkWell(
                  onTap: () => onOpen(v['url']?.toString()),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceAlt),
                    ),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumb.isNotEmpty
                            ? Image.network(thumb, width: 88, height: 50, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                    width: 88, height: 50, color: AppColors.surfaceAlt,
                                    child: const Icon(Icons.play_circle_rounded, color: AppColors.gold)),
                              )
                            : Container(
                                width: 88, height: 50, color: AppColors.surfaceAlt,
                                child: const Icon(Icons.play_circle_rounded, color: AppColors.gold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Row(children: [
                            Expanded(
                              child: Text(chan,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
                            ),
                            if (dur != null)
                              Text(_fmtDur(dur),
                                  style: const TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordRow(String label, String lap, String driver, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ),
        Text(lap, style: const TextStyle(color: AppColors.goldLight, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$driver · $date',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
        ),
      ]),
    );
  }
}

/// Franja de estado LFM en vivo: usuarios online, servidores, comunidad.
/// Carga ligera (endpoint con caché 5 min en BD) — falla silencioso.
class _LfmStatusStrip extends StatefulWidget {
  @override
  State<_LfmStatusStrip> createState() => _LfmStatusStripState();
}

class _LfmStatusStripState extends State<_LfmStatusStrip> {
  Map<String, dynamic>? _data;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/api/global/status');
      if (!mounted) return;
      setState(() { _data = Map<String, dynamic>.from(d as Map); _loaded = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loaded = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _data == null) return const SizedBox.shrink();
    final online = ((_data?['online_users'] as Map?)?['online_users'] as num?)?.toInt();
    final acc = ((_data?['accstatus'] as Map?)?['server_status'] as num?)?.toInt();
    final lfmplus = ((_data?['lfmplus'] as Map?)?['members'] as num?)?.toInt();
    final sims = ((_data?['simulations'] as List?) ?? []).cast<Map>();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Row(children: [
        Icon(online != null && online > 0 ? Icons.circle : Icons.circle_outlined,
            color: online != null && online > 0 ? AppColors.green : AppColors.textDim, size: 10),
        const SizedBox(width: 8),
        Text(online != null ? '$online pilotos en LFM' : 'LFM conectado',
            style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
        const Spacer(),
        if (acc != null && acc == 1)
          const _StatusDot(label: 'ACC', color: AppColors.green),
        if (lfmplus != null)
          _StatusDot(label: '$lfmplus LFM+', color: AppColors.gold),
        if (sims.isNotEmpty)
          Text('${sims.length} sims', style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
      ]),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusDot({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, color: color, size: 8),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
      ]),
    );
  }
}
