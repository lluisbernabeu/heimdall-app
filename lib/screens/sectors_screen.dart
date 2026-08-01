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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${m['track_name']}',
                style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
          ),
          Text('Split ${m['split']}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ]),
        Text('${m['race_date']?.toString().substring(0, 10)}',
            style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _sectorCol('S1', m['my_s1'], m['best_s1'], gapColor(m['gap_s1_ms']), gapStr(m['gap_s1_ms']), fmt)),
          Expanded(child: _sectorCol('S2', m['my_s2'], m['best_s2'], gapColor(m['gap_s2_ms']), gapStr(m['gap_s2_ms']), fmt)),
          Expanded(child: _sectorCol('S3', m['my_s3'], m['best_s3'], gapColor(m['gap_s3_ms']), gapStr(m['gap_s3_ms']), fmt)),
        ]),
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
