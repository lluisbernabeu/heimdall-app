import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Comparativa: tú vs cualquier piloto del sistema (tus perfiles u otros).
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  List<Map<String, dynamic>> _profiles = [];
  int? _a, _b;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await ApiClient.get('/api/me');
      final mine = (me['profiles'] as List? ?? []).cast<Map>();
      final all = (await ApiClient.get('/api/profiles') as List).cast<Map>();
      final profiles = <Map<String, dynamic>>[
        for (final p in mine) Map<String, dynamic>.from(p),
        for (final p in all)
          if (!mine.any((m) => m['id'] == p['id']))
            Map<String, dynamic>.from(p),
      ];
      setState(() {
        _profiles = profiles;
        if (profiles.isNotEmpty) _a = (profiles.first)['id'] as int;
        // Por defecto B = el primero que no sea A (Josema)
        if (profiles.length >= 2) {
          _b = profiles.firstWhere(
              (p) => p['id'] != _a, orElse: () => profiles.first)['id'] as int;
        }
        _loading = false;
      });
      if (_a != null && _b != null) await _compare();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _compare() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('/api/profile/$_a/compare/$_b');
      setState(() { _data = Map<String, dynamic>.from(data as Map); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar pilotos')),
      body: _loading && _data == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(32),
                  child: Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.red))))
              : _profiles.length < 2
                  ? const Center(child: Padding(padding: EdgeInsets.all(32),
                      child: Text('Necesitas al menos 2 pilotos con datos para comparar.\n'
                          'Sincroniza tu perfil o el de otro piloto.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim))))
                  : _body(),
    );
  }

  Widget _body() {
    final a = Map<String, dynamic>.from((_data?['a'] as Map? ?? {}));
    final b = Map<String, dynamic>.from((_data?['b'] as Map? ?? {}));
    return RefreshIndicator(
      onRefresh: _compare,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selectores
          Row(children: [
            Expanded(child: _picker(_a, (v) { _a = v; _compare(); }, 'A')),
            const SizedBox(width: 12),
            Expanded(child: _picker(_b, (v) { _b = v; _compare(); }, 'B')),
          ]),
          const SizedBox(height: 20),

          // Cabeceras
          Row(children: [
            Expanded(child: _header(a)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS', style: TextStyle(color: AppColors.gold,
                    fontWeight: FontWeight.w900, fontSize: 16))),
            Expanded(child: _header(b)),
          ]),
          const SizedBox(height: 16),

          // Métricas
          _row('Carreras', '${a['races'] ?? 0}', '${b['races'] ?? 0}'),
          _row('Victorias', '${a['wins'] ?? 0}', '${b['wins'] ?? 0}'),
          _row('Podios', '${a['podiums'] ?? 0}', '${b['podiums'] ?? 0}'),
          _row('Avg finish', '${a['avg_finish'] ?? '—'}', '${b['avg_finish'] ?? '—'}'),
          _row('Avg incidentes', '${a['avg_incidents'] ?? '—'}', '${b['avg_incidents'] ?? '—'}'),
          _row('Mejor vuelta', a['best_lap'] ?? '—', b['best_lap'] ?? '—'),
          _row('Consistencia (σ)', '${a['consistency_std_ms'] != null ? (a['consistency_std_ms'] / 1000).toStringAsFixed(3) + 's' : '—'}',
              '${b['consistency_std_ms'] != null ? (b['consistency_std_ms'] / 1000).toStringAsFixed(3) + 's' : '—'}'),
          _row('Licencia', '${a['license'] ?? '—'}', '${b['license'] ?? '—'}'),
          _row('SR', '${a['safety_rating'] ?? '—'}', '${b['safety_rating'] ?? '—'}'),
          _row('Rating', '${a['rating'] ?? '—'}', '${b['rating'] ?? '—'}'),
        ],
      ),
    );
  }

  Widget _picker(int? sel, ValueChanged<int> onSel, String tag) {
    return DropdownButtonFormField<int>(
      initialValue: sel,
      dropdownColor: AppColors.surfaceAlt,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: 'Piloto $tag',
        labelStyle: const TextStyle(color: AppColors.textDim),
      ),
      items: [
        for (final p in _profiles)
          DropdownMenuItem(
            value: p['id'] as int,
            child: Text('${p['username'] ?? p['vorname'] ?? ''} ${p['nachname'] ?? ''}'.trim(),
                style: const TextStyle(fontSize: 13)),
          ),
      ],
      onChanged: (v) { if (v != null) onSel(v); },
    );
  }

  Widget _header(Map m) {
    return Column(children: [
      ClipOval(
        child: ((m['avatar'] as String?) ?? '').isNotEmpty
            ? Image.network(m['avatar'] as String, width: 52, height: 52, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person, color: AppColors.textDim))
            : const Icon(Icons.person, color: AppColors.textDim, size: 52),
      ),
      const SizedBox(height: 6),
      Text('${m['name'] ?? '—'}', textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
    ]);
  }

  Widget _row(String label, String va, String vb) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Row(children: [
        Expanded(
          child: Text(va, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gold,
                  fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        SizedBox(width: 110,
            child: Text(label, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11.5))),
        Expanded(
          child: Text(vb, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.cyan,
                  fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ]),
    );
  }
}
