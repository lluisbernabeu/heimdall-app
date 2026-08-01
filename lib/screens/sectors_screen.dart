import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Análisis de sectores: tus mejores S1/S2/S3 vs el mejor de cada carrera.
class SectorsScreen extends StatefulWidget {
  const SectorsScreen({super.key});
  @override
  State<SectorsScreen> createState() => _SectorsScreenState();
}

class _SectorsScreenState extends State<SectorsScreen> {
  List<dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await ApiClient.get('/api/me');
      final pid = ((me['profiles'] as List).first as Map)['id'] as int;
      final data = await ApiClient.get('/api/profile/$pid/sectors');
      setState(() { _data = data as List; _loading = false; });
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
      appBar: AppBar(title: const Text('Sectores (S1/S2/S3)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _data!.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(32),
                      child: Text('Aún no hay vueltas detalladas. Sincroniza para descargar los tiempos por sector.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim))))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Comparativa de tus mejores sectores vs el más rápido del split',
                            style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                        const SizedBox(height: 12),
                        ..._data!.map((e) {
                          final m = Map<String, dynamic>.from(e as Map);
                          return _SectorCard(m: m, fmt: _fmt);
                        }),
                      ],
                    ),
    );
  }
}

class _SectorCard extends StatelessWidget {
  final Map<String, dynamic> m;
  final String Function(num?) fmt;
  const _SectorCard({required this.m, required this.fmt});

  @override
  Widget build(BuildContext context) {
    Color gapColor(num? gap) =>
        gap == null ? AppColors.textDim : (gap <= 0 ? AppColors.green : AppColors.red);
    String gapStr(num? gap) =>
        gap == null ? '—' : (gap <= 0 ? '±0' : '+${(gap / 1000).toStringAsFixed(3)}s');
    final g1 = (m['gap_s1_ms'] as num?)?.toDouble();
    final g2 = (m['gap_s2_ms'] as num?)?.toDouble();
    final g3 = (m['gap_s3_ms'] as num?)?.toDouble();
    final totalGap = [g1, g2, g3].whereType<double>().fold<double>(0, (a, b) => a + b);
    // Color dominante de la tarjeta según el mayor gap
    final worst = [g1 ?? 0, g2 ?? 0, g3 ?? 0].reduce((a, b) => a > b ? a : b);
    final Color accent = worst > 0 ? AppColors.red : AppColors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.10), AppColors.surface],
          stops: const [0.0, 0.6],
        ),
        border: Border.all(color: accent.withValues(alpha: worst > 0 ? 0.35 : 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${m['track_name']}',
                style: const TextStyle(color: AppColors.text,
                    fontWeight: FontWeight.w800, fontSize: 14.5)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
            ),
            child: Text('Split ${m['split']}',
                style: const TextStyle(color: AppColors.cyan, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.calendar_today, color: AppColors.textDim, size: 11),
          const SizedBox(width: 4),
          Text(fmtDate(m['race_date']),
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _sectorCol('S1', m['my_s1'], m['best_s1'], gapColor(m['gap_s1_ms']), gapStr(m['gap_s1_ms']), fmt)),
          Expanded(child: _sectorCol('S2', m['my_s2'], m['best_s2'], gapColor(m['gap_s2_ms']), gapStr(m['gap_s2_ms']), fmt)),
          Expanded(child: _sectorCol('S3', m['my_s3'], m['best_s3'], gapColor(m['gap_s3_ms']), gapStr(m['gap_s3_ms']), fmt)),
        ]),
        if (totalGap > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                'Sumando tus gaps pierdes +${(totalGap / 1000).toStringAsFixed(3)}s por vuelta vs el más rápido',
                style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  Widget _sectorCol(String label, String? mine, String? best, Color gapColor, String gapStr, String Function(num?) fmt) {
    return Column(children: [
      Text(label, style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: 12)),
      const SizedBox(height: 4),
      Text(mine ?? '—', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
      Text('top ${best ?? '—'}', style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      Text(gapStr, style: TextStyle(color: gapColor, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}
