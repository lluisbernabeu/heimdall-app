import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'loading_screen.dart';
import 'race_detail_screen.dart';

/// Home: qué está pasando (insight) + acceso a análisis.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _insight;
  int? _profileId;
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
      final profiles = (me['profiles'] as List? ?? []);
      if (profiles.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/link');
        return;
      }
      final pid = (profiles.first as Map)['id'] as int;
      final results = await Future.wait([
        ApiClient.get('/api/profile/$pid/overview'),
        ApiClient.get('/api/profile/$pid/insight'),
      ]);
      setState(() {
        _profileId = pid;
        _data = Map<String, dynamic>.from(results[0] as Map);
        _insight = Map<String, dynamic>.from(results[1] as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const HeimdallLogo(size: 34),
          const SizedBox(width: 10),
          const Text('Heimdall'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.sync, color: AppColors.cyan),
            tooltip: 'Sincronizar',
            onPressed: _profileId == null ? null : () async {
              try {
                await ApiClient.post('/api/profile/$_profileId/sync');
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LoadingScreen(profileId: _profileId!)));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textDim),
            onPressed: () async {
              await ApiClient.clearToken();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? _ErrorView(msg: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Color _toneColor(String tone) {
    switch (tone) {
      case 'red': return AppColors.red;
      case 'green': return AppColors.green;
      case 'orange': return const Color(0xFFE8A33D);
      default: return AppColors.cyan;
    }
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'shield': return Icons.shield_rounded;
      case 'sector': return Icons.timer_outlined;
      case 'trophy': return Icons.emoji_events_rounded;
      case 'target': return Icons.flag_rounded;
      default: return Icons.lightbulb_outline;
    }
  }

  Widget _buildBody() {
    final d = _data!;
    final p = (d['profile'] as Map? ?? {});
    final ins = _insight;
    final verdict = (ins?['verdict'] as Map? ?? {});
    final insights = (ins?['insights'] as List? ?? []);
    final action = (ins?['action'] as Map? ?? {});
    final lastRaces = (d['last_races'] as List? ?? []);
    final vColor = _toneColor(verdict['tone']?.toString() ?? 'cyan');

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          // ---- Cabecera piloto compacta ----
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A2C44), Color(0xFF0D1B2E)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.goldLight, AppColors.gold],
                  ),
                ),
                child: ClipOval(
                  child: (p['avatar'] as String? ?? '').isNotEmpty
                      ? Image.network(p['avatar'] as String,
                          width: 54, height: 54, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _AvatarFallback())
                      : const _AvatarFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['vorname'] ?? ''} ${p['nachname'] ?? ''}'.trim().isEmpty
                      ? (p['username'] ?? 'Piloto').toString()
                      : '${p['vorname'] ?? ''} ${p['nachname'] ?? ''}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _Badge(text: p['license']?.toString() ?? '—', color: AppColors.cyan),
                    _Badge(text: 'SR ${p['safety_rating']?.toString() ?? '—'}', color: AppColors.green),
                    if (p['origin'] != null) _Badge(text: p['origin'].toString(), color: AppColors.gold),
                  ]),
                ]),
              ),
            ]),
          ),

          // ---- VEREDICTO (lo importante) ----
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  vColor.withValues(alpha: 0.22),
                  AppColors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: vColor.withValues(alpha: 0.55), width: 1.2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${verdict['emoji'] ?? '📊'}',
                    style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${verdict['title'] ?? 'Estado'}',
                      style: TextStyle(
                          color: vColor, fontSize: 22, fontWeight: FontWeight.w900,
                          letterSpacing: 0.3)),
                ),
              ]),
              const SizedBox(height: 10),
              Text('${verdict['msg'] ?? ''}',
                  style: const TextStyle(color: AppColors.text, fontSize: 14.5, height: 1.4)),
            ]),
          ),

          // ---- Señales interpretadas ----
          ...insights.map<Widget>((raw) {
            final i = Map<String, dynamic>.from(raw as Map);
            final c = _toneColor(i['tone']?.toString() ?? 'cyan');
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceAlt),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_iconFor(i['icon']?.toString() ?? ''), color: c, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i['title'] ?? ''}',
                        style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('${i['msg'] ?? ''}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.35)),
                  ]),
                ),
              ]),
            );
          }),

          // ---- Qué hacer ahora ----
          if (action.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF16283C), Color(0xFF0D1B2E)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [AppColors.goldLight, AppColors.gold],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_iconFor(action['icon']?.toString() ?? 'target'),
                      color: const Color(0xFF0A1420), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('QUÉ HACER AHORA',
                        style: TextStyle(color: AppColors.gold, fontSize: 10.5,
                            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text('${action['title'] ?? ''}',
                        style: const TextStyle(color: AppColors.text, fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${action['msg'] ?? ''}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.35)),
                  ]),
                ),
              ]),
            ),
          ],

          // ---- Accesos rápidos ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text('Análisis',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _ActionRow(icon: Icons.show_chart, label: 'Progresión',
                  onTap: () => _push('/analysis/progression')),
              _ActionRow(icon: Icons.timer_outlined, label: 'Sectores',
                  onTap: () => _push('/analysis/sectors')),
              _ActionRow(icon: Icons.speed, label: 'Consistencia',
                  onTap: () => _push('/analysis/consistency')),
              _ActionRow(icon: Icons.report, label: 'Incidentes',
                  onTap: () => _push('/analysis/incidents')),
              _ActionRow(icon: Icons.compare_arrows, label: 'Comparar',
                  onTap: () => _push('/analysis/compare')),
            ]),
          ),

          // ---- Últimas carreras ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(children: [
              Text('Últimas carreras',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const Spacer(),
              TextButton(
                onPressed: () => _push('/analysis/races'),
                child: const Text('Ver todas', style: TextStyle(color: AppColors.cyan)),
              ),
            ]),
          ),
          ...lastRaces.take(5).map<Widget>((r) => _RaceTile(
                r: Map<String, dynamic>.from(r as Map),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RaceDetailScreen(
                        profileId: _profileId!, raceId: r['race_id'] as int))),
              )),
          if (lastRaces.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Sin carreras todavía. Pulsa el icono de sincronizar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDim)),
            ),
        ],
      ),
    );
  }

  void _push(String route) {
    if (route == '/analysis/races') {
      Navigator.of(context).pushNamed(route, arguments: _profileId);
      return;
    }
    Navigator.of(context).pushNamed(route);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54, height: 54,
      color: AppColors.surfaceAlt,
      child: const Icon(Icons.person, color: AppColors.textDim, size: 30),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceAlt),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.cyan, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 14,
                fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textDim, size: 20),
        ]),
      ),
    );
  }
}

class _RaceTile extends StatelessWidget {
  final Map<String, dynamic> r; final VoidCallback onTap;
  const _RaceTile({required this.r, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final pos = r['finish_pos'];
    final Color posColor = pos == 1 ? AppColors.gold : pos <= 3 ? AppColors.cyan : AppColors.text;
    final rc = (r['rating_change'] as num?)?.toDouble();
    final sc = (r['sr_change'] as num?)?.toDouble();
    final bow = r['best_of_week'] == true;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceAlt),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [posColor.withValues(alpha: 0.28), posColor.withValues(alpha: 0.10)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: posColor.withValues(alpha: 0.5), width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text('$pos',
                style: TextStyle(color: posColor, fontSize: 17, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(r['track_name']?.toString() ?? '',
                      style: const TextStyle(color: AppColors.text, fontSize: 14,
                          fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (bow) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star, color: AppColors.gold, size: 14),
                ],
              ]),
              Text('${r['event_name']} · ${r['race_date']?.toString().substring(0, 10)}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rc == null ? '—' : (rc > 0 ? '+${rc.toStringAsFixed(0)}' : rc.toStringAsFixed(0)),
                style: TextStyle(color: (rc ?? 0) >= 0 ? AppColors.green : AppColors.red,
                    fontSize: 13, fontWeight: FontWeight.w800)),
            Text(sc == null ? '' : (sc > 0 ? '+${sc.toStringAsFixed(2)}' : sc.toStringAsFixed(2)),
                style: TextStyle(color: (sc ?? 0) >= 0 ? AppColors.green : AppColors.red,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String msg; final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, color: AppColors.red, size: 48),
          const SizedBox(height: 16),
          Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      ),
    );
  }
}
