import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Vista Circuito — responde a "¿Cómo estoy en este circuito?".
/// Estructura mínima: selector + tarjeta principal (mapa de fondo, tu vuelta
/// vs el más rápido, gap) + splits en una línea + récords.
class CircuitScreen extends StatefulWidget {
  const CircuitScreen({super.key});
  @override
  State<CircuitScreen> createState() => _CircuitScreenState();
}

class _CircuitScreenState extends State<CircuitScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String? _selectedTrack;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load([String? trackName]) async {
    setState(() { _loading = true; _error = null; });
    try {
      final me = await ApiClient.get('/api/me');
      final pid = ((me['profiles'] as List).first as Map)['id'] as int;
      final q = trackName != null
          ? '?track_name=${Uri.encodeQueryComponent(trackName)}'
          : '';
      final data = await ApiClient.get('/api/profile/$pid/circuit$q');
      setState(() {
        _data = Map<String, dynamic>.from(data as Map);
        _selectedTrack = trackName;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _fmt(num? ms) => fmtLap(ms);

  String _fmtGap(num? ms) {
    if (ms == null) return '—';
    if (ms == 0) return '+0.000';
    final s = ms.abs() / 1000.0;
    return '${ms > 0 ? '+' : '-'}${s.toStringAsFixed(3)}';
  }

  /// Bandera emoji a partir del código ISO de 2 letras.
  String _flag(String? iso) {
    if (iso == null || iso.length != 2) return '🏁';
    return String.fromCharCodes(iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
  }

  Future<void> _pickTrack(List<Map> available, String currentName) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(children: [
                Icon(Icons.flag_rounded, color: AppColors.gold, size: 18),
                SizedBox(width: 8),
                Text('Tus circuitos',
                    style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Toca un circuito para cargar su mapa y tus tiempos.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 11.5)),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  for (final t in available) ...[
                    _TrackOption(
                      name: t['name']?.toString() ?? '—',
                      flag: _flag(t['country']?.toString()),
                      detail: [
                        if (t['country'] != null) t['country'].toString(),
                        if (t['turns'] != null) '${t['turns']} curvas',
                        if (t['km'] != null) '${((t['km'] as num) / 1000).toStringAsFixed(1)} km',
                        if (t['races'] != null) '${t['races']} ${(t['races'] as num) == 1 ? 'carrera' : 'carreras'}',
                      ].join(' · '),
                      selected: t['name'] == currentName,
                      onTap: () => Navigator.pop(ctx, t['name']?.toString()),
                    ),
                    if (t['name'] != available.last['name']) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ]),
        );
      },
    );
    if (picked != null && picked != currentName) _load(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Circuito')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _body(),
    );
  }

  Widget _body() {
    final track = Map<String, dynamic>.from(_data!['track'] as Map? ?? {});
    final rb = Map<String, dynamic>.from(_data!['race_breakdown'] as Map? ?? {});
    final rec = Map<String, dynamic>.from(_data!['records'] as Map? ?? {});
    final splits = Map<String, dynamic>.from(rb['splits'] as Map? ?? {});
    final mine = Map<String, dynamic>.from(splits['mine'] as Map? ?? {});
    final fastest = Map<String, dynamic>.from(splits['fastest'] as Map? ?? {});
    final top5 = (rec['top5'] as List? ?? []).cast<Map>();
    final myRank = rec['my_rank'] as int?;
    final totalDrivers = rec['total_drivers'] as int?;
    final available = ((_data!['available_tracks'] as List?) ?? []).cast<Map>();
    final currentName = _selectedTrack ?? track['track_name']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Selector de circuito (todos donde has corrido) ----
        if (available.length > 1) ...[
          _TrackSelector(
            name: currentName,
            flag: _flag(track['country']?.toString()),
            detail: [
              if (track['country'] != null) track['country'].toString(),
              if (track['turns'] != null) '${track['turns']} curvas',
              if (track['km'] != null) '${((track['km'] as num) / 1000).toStringAsFixed(1)} km',
            ].join(' · '),
            onTap: () => _pickTrack(available, currentName),
          ),
          const SizedBox(height: 12),
        ],

        // ---- Tarjeta principal: mapa pintado por sectores + tu vuelta vs el más rápido ----
        _MainCard(track: track, rb: rb, mine: mine, fastest: fastest, fmt: _fmt, fmtGap: _fmtGap),
        const SizedBox(height: 12),

        // ---- Splits en una línea ----
        _SplitsRow(mine: mine, fastest: fastest, fmt: _fmt, fmtGap: _fmtGap),
        const SizedBox(height: 16),

        // ---- Récords en este circuito ----
        Text('Récords en ${track['track_name'] ?? 'este circuito'}',
            style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Mejor vuelta de los pilotos de tus splits con el mismo coche.',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceAlt),
          ),
          child: Column(children: [
            for (int i = 0; i < top5.length; i++) ...[
              _RecordRow(index: i + 1, driver: top5[i]['driver']?.toString() ?? '—',
                  time: _fmt(top5[i]['best_ms'] as num?),
                  highlight: myRank != null && myRank == i + 1),
              if (i < top5.length - 1) const Divider(height: 1, color: AppColors.surfaceAlt),
            ],
          ]),
        ),
        if (myRank != null && myRank > 5) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.flag_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu mejor: #$myRank de $totalDrivers pilotos (${rec['my_best_fmt'] ?? '—'})',
                  style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Selector de circuito: tarjeta oscura con bandera + nombre + botón cambiar.
class _TrackSelector extends StatelessWidget {
  final String name;
  final String flag;
  final String detail;
  final VoidCallback onTap;
  const _TrackSelector({required this.name, required this.flag, required this.detail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
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
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(detail,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 15),
                SizedBox(width: 4),
                Text('Cambiar', style: TextStyle(color: AppColors.gold, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Opción del bottom sheet de circuitos.
class _TrackOption extends StatelessWidget {
  final String name;
  final String flag;
  final String detail;
  final bool selected;
  final VoidCallback onTap;
  const _TrackOption({required this.name, required this.flag, required this.detail, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: 0.10) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.gold : AppColors.surfaceAlt),
          ),
          child: Row(children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: TextStyle(
                        color: selected ? AppColors.goldLight : AppColors.text,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
              ]),
            ),
            if (selected) ...[
              const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 4),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Tarjeta principal: mapa del circuito PINTADO por sectores (rojo = pierdes,
/// verde = ganas) bien visible, con tu mejor vuelta vs el más rápido encima.
class _MainCard extends StatefulWidget {
  final Map<String, dynamic> track;
  final Map<String, dynamic> rb;
  final Map<String, dynamic> mine;
  final Map<String, dynamic> fastest;
  final String Function(num?) fmt;
  final String Function(num?) fmtGap;
  const _MainCard({required this.track, required this.rb, required this.mine,
    required this.fastest, required this.fmt, required this.fmtGap});

  @override
  State<_MainCard> createState() => _MainCardState();
}

class _MainCardState extends State<_MainCard> {
  Uint8List? _mapBytes;
  bool _mapLoading = true;
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    setState(() { _mapLoading = true; _mapError = null; });
    try {
      final trackId = widget.track['track_id'];
      final mine = widget.mine;
      final fastest = widget.fastest;
      // Si no hay ninguna referencia de rival (ni en la carrera ni en el
      // historial), no pintar el mapa: sería todo rojo engañoso.
      final hasRival = ((fastest['s1_ms'] as num?) ?? (fastest['s2_ms'] as num?) ?? (fastest['s3_ms'] as num?)) != null;
      if (!hasRival) {
        if (!mounted) return;
        setState(() {
          _mapError = 'Sin vueltas de rivales en este circuito para comparar.';
          _mapLoading = false;
        });
        return;
      }
      // Deltas por sector (ms): positivo = pierdes (rojo), negativo = ganas (verde)
      int d(String k) => (((mine[k] as num?) ?? 0) - ((fastest[k] as num?) ?? 0)).round();
      final s1 = d('s1_ms'), s2 = d('s2_ms'), s3 = d('s3_ms');
      // Duración real de cada sector (proporción del trazado)
      int t(String k) => ((mine[k] as num?) ?? 0).round();
      final t1 = t('s1_ms'), t2 = t('s2_ms'), t3 = t('s3_ms');
      final path = '/api/trackmap/$trackId/colored?s1=$s1&s2=$s2&s3=$s3&t1=$t1&t2=$t2&t3=$t3';
      final bytes = await ApiClient.getBytes(path);
      if (!mounted) return;
      setState(() { _mapBytes = bytes; _mapLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _mapError = e.toString().replaceFirst('Exception: ', ''); _mapLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.rb['gap_ms'] as num?;
    final lose = (gap ?? 0) > 0;
    final rb = widget.rb;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF221A10), Color(0xFF16110A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- Cabecera: última carrera + TÚ vs MÁS RÁPIDO + gap ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Última carrera (${rb['event_name'] ?? ''})',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('TÚ', style: TextStyle(color: AppColors.goldLight, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 3),
                  Text(widget.fmt(rb['my_best_ms'] as num?),
                      style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('mejor vuelta', style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
                ]),
              ),
              Container(width: 1, height: 48, color: AppColors.textDim.withValues(alpha: 0.3)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('MÁS RÁPIDO', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 3),
                  Text(widget.fmt(rb['fastest_ms'] as num?),
                      style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text(rb['fastest_source'] == 'record'
                      ? 'récord del circuito'
                      : (rb['fastest_driver']?.toString() ?? ''),
                      style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (lose ? AppColors.red : AppColors.green).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (lose ? AppColors.red : AppColors.green).withValues(alpha: 0.45)),
              ),
              child: Row(children: [
                Icon(lose ? Icons.timer_outlined : Icons.verified_rounded,
                    color: lose ? AppColors.red : AppColors.green, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gap == null
                        ? 'Sin datos de rivales en esta carrera.'
                        : (lose
                            ? 'Le sacas ${widget.fmtGap(gap)} por vuelta al más rápido.'
                            : '¡Igualas o superas al más rápido!'),
                    style: TextStyle(
                        color: lose ? AppColors.red : AppColors.green,
                        fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        // ---- Mapa pintado por sectores (protagonista, visible) ----
        Container(
          width: double.infinity,
          color: AppColors.bg,
          padding: const EdgeInsets.all(10),
          child: _mapLoading
              ? const SizedBox(
                  height: 170,
                  child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5)),
                )
              : _mapError != null
                  ? SizedBox(
                      height: 170,
                      child: Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.map_outlined, color: AppColors.textDim, size: 36),
                          const SizedBox(height: 6),
                          Text('Mapa no disponible', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(_mapError!, style: const TextStyle(color: AppColors.textDim, fontSize: 9),
                              textAlign: TextAlign.center),
                        ]),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _mapBytes!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        gaplessPlayback: true,
                      ),
                    ),
        ),
        // ---- Leyenda compacta ----
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.circle, color: AppColors.red, size: 9),
            SizedBox(width: 4),
            Text('Pierdes', style: TextStyle(color: AppColors.textDim, fontSize: 10.5)),
            SizedBox(width: 14),
            Icon(Icons.circle, color: AppColors.green, size: 9),
            SizedBox(width: 4),
            Text('Ganas', style: TextStyle(color: AppColors.textDim, fontSize: 10.5)),
            SizedBox(width: 14),
            Icon(Icons.flag_rounded, color: AppColors.gold, size: 11),
            SizedBox(width: 4),
            Text('Meta', style: TextStyle(color: AppColors.textDim, fontSize: 10.5)),
          ]),
        ),
      ]),
    );
  }
}

/// Splits en una línea: S1/S2/S3 como 3 columnas compactas.
class _SplitsRow extends StatelessWidget {
  final Map<String, dynamic> mine;
  final Map<String, dynamic> fastest;
  final String Function(num?) fmt;
  final String Function(num?) fmtGap;
  const _SplitsRow({required this.mine, required this.fastest, required this.fmt, required this.fmtGap});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('S1', 's1_ms'), ('S2', 's2_ms'), ('S3', 's3_ms'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text('Desglose por sector',
              style: TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
        Row(children: [
          for (final (label, key) in rows) ...[
            Expanded(child: _SectorColumn(label: label, myMs: mine[key] as num?,
                fsMs: fastest[key] as num?, fmt: fmt, fmtGap: fmtGap)),
            if (label != 'S3') const SizedBox(width: 8),
          ],
        ]),
      ]),
    );
  }
}

class _SectorColumn extends StatelessWidget {
  final String label;
  final num? myMs;
  final num? fsMs;
  final String Function(num?) fmt;
  final String Function(num?) fmtGap;
  const _SectorColumn({required this.label, required this.myMs, required this.fsMs, required this.fmt, required this.fmtGap});

  @override
  Widget build(BuildContext context) {
    final gap = (myMs != null && fsMs != null) ? myMs! - fsMs! : null;
    final lose = (gap ?? 0) > 0;
    final accent = lose ? AppColors.red : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: gap == null ? AppColors.surfaceAlt : accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gap == null ? AppColors.surfaceAlt : accent.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(
            color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(fmt(myMs), style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(fmt(fsMs), style: const TextStyle(color: AppColors.textDim, fontSize: 10.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(fmtGap(gap),
              style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }
}

/// Fila del ranking de récords.
class _RecordRow extends StatelessWidget {
  final int index;
  final String driver;
  final String time;
  final bool highlight;
  const _RecordRow({required this.index, required this.driver, required this.time, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final c = highlight ? AppColors.goldLight : AppColors.textDim;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 26,
          child: Text('#$index',
              style: TextStyle(
                  color: index <= 3 ? AppColors.gold : AppColors.textDim,
                  fontSize: 12, fontWeight: FontWeight.w900)),
        ),
        Expanded(
          child: Text(driver,
              style: TextStyle(
                  color: highlight ? AppColors.goldLight : AppColors.text,
                  fontSize: 12.5, fontWeight: highlight ? FontWeight.w900 : FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (highlight) ...[
          const Icon(Icons.person_pin_circle, color: AppColors.goldLight, size: 14),
          const SizedBox(width: 4),
        ],
        Text(time, style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
