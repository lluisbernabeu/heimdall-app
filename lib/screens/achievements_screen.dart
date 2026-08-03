import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Logros — gamificación del piloto: achievements LFM (con progreso) y
/// rating por simulador. Datos guardados en BD durante el sync (regla nº1).
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
      final d = await ApiClient.get('/api/profile/$pid/achievements');
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
      appBar: AppBar(title: const Text('Logros')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? _ErrorView(msg: _error!, onRetry: _load)
              : _body(),
    );
  }

  Widget _body() {
    final achievements = (_data?['achievements'] as Map? ?? {});
    final ratingBySim = ((_data?['rating_by_sim'] as List?) ?? []).cast<Map>();
    final categories = achievements.entries.toList();

    // Total desbloqueado
    int unlocked = 0, total = 0;
    for (final entry in categories) {
      for (final a in (entry.value as List? ?? []).cast<Map>()) {
        total++;
        if (a['unlocked'] == true) unlocked++;
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Resumen
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
            child: Row(children: [
              const Icon(Icons.military_tech_rounded, color: AppColors.gold, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$unlocked / $total logros',
                      style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(total > 0
                      ? '${(unlocked * 100 / total).toStringAsFixed(0)}% desbloqueado'
                      : 'Sin logros todavía',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                ]),
              ),
              _progressRing(unlocked / (total == 0 ? 1 : total)),
            ]),
          ),

          // Rating por simulador
          if (ratingBySim.isNotEmpty) ...[
            _sectionTitle('RATING POR SIMULADOR'),
            for (final s in ratingBySim) _simCard(s),
          ],

          // Categorías de logros
          _sectionTitle('LOGROS'),
          for (final entry in categories)
            _categoryCard(entry.key, (entry.value as List? ?? []).cast<Map>()),
        ],
      ),
    );
  }

  Widget _progressRing(double frac) {
    return SizedBox(
      width: 52, height: 52,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 52, height: 52,
          child: CircularProgressIndicator(
            value: frac.clamp(0.0, 1.0),
            strokeWidth: 5,
            color: AppColors.gold,
            backgroundColor: AppColors.surfaceAlt,
          ),
        ),
        Text('${(frac * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _simCard(Map s) {
    final name = s['name']?.toString() ?? '—';
    final rating = s['rating'];
    final lic = s['license']?.toString() ?? '';
    final races = s['ranked_races'] as num? ?? 0;
    final logo = s['logo_url']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Row(children: [
        if (logo.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(logo, width: 30, height: 30, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.videogame_asset_rounded,
                    color: AppColors.textDim, size: 26)),
          )
        else
          const Icon(Icons.videogame_asset_rounded, color: AppColors.textDim, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('$races carreras ranked', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ]),
        ),
        if (lic.isNotEmpty)
          _Badge(text: lic, color: AppColors.gold),
        const SizedBox(width: 8),
        Text('$rating', style: const TextStyle(color: AppColors.goldLight, fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _categoryCard(String category, List<Map> items) {
    final unlocked = items.where((a) => a['unlocked'] == true).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(unlocked > 0 ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
            color: unlocked > 0 ? AppColors.gold : AppColors.textDim),
        title: Text(_prettyCat(category),
            style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
        subtitle: Text('$unlocked/${items.length} desbloqueados',
            style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [for (final a in items) _achievementRow(a)],
      ),
    );
  }

  Widget _achievementRow(Map a) {
    final name = a['name']?.toString() ?? '—';
    final desc = a['description']?.toString() ?? '';
    final unlocked = a['unlocked'] == true;
    final progress = a['progress'];
    final target = a['points_to_unlock'];

    double frac = 0;
    try {
      final p = double.parse('$progress');
      final t = double.parse('$target');
      if (t > 0) frac = (p / t).clamp(0.0, 1.0);
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(unlocked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: unlocked ? AppColors.green : AppColors.textDim, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(
                color: unlocked ? AppColors.green : AppColors.text,
                fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              color: unlocked ? AppColors.green : AppColors.gold,
              backgroundColor: AppColors.surfaceAlt,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$progress/$target', style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      ]),
    );
  }

  String _prettyCat(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) =>
        w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(t,
          style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
