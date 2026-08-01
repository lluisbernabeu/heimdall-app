import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'loading_screen.dart';
import 'race_detail_screen.dart';

/// Home: resumen del piloto + KPIs principales.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
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
      final data = await ApiClient.get('/api/profile/$pid/overview');
      setState(() {
        _profileId = pid;
        _data = Map<String, dynamic>.from(data as Map);
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

  Widget _buildBody() {
    final d = _data!;
    final p = (d['profile'] as Map? ?? {});
    final s = (d['stats'] as Map? ?? {});
    final lastRaces = (d['last_races'] as List? ?? []);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          // Cabecera del piloto
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A2C44), Color(0xFF0D1B2E)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18, offset: const Offset(0, 8),
                ),
              ],
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
                          width: 62, height: 62, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _AvatarFallback())
                      : const _AvatarFallback(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['vorname'] ?? ''} ${p['nachname'] ?? ''}'.trim().isEmpty
                      ? (p['username'] ?? 'Piloto').toString()
                      : '${p['vorname'] ?? ''} ${p['nachname'] ?? ''}',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _Badge(text: p['license']?.toString() ?? '—',
                        color: AppColors.cyan),
                    const SizedBox(width: 6),
                    _Badge(text: 'SR ${p['safety_rating']?.toString() ?? '—'}',
                        color: AppColors.green),
                    const SizedBox(width: 6),
                    if (p['origin'] != null)
                      _Badge(text: p['origin'].toString(), color: AppColors.gold),
                  ]),
                  if (p['team_name'] != null) ...[
                    const SizedBox(height: 6),
                    Text('Equipo: ${p['team_name']}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                  ],
                ]),
              ),
            ]),
          ),

          // Stat cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _StatCard(label: 'Carreras', value: '${s['races'] ?? 0}',
                  icon: Icons.flag, color: AppColors.cyan),
              _StatCard(label: 'Podios', value: '${s['podiums'] ?? 0}',
                  icon: Icons.emoji_events, color: AppColors.gold),
              _StatCard(label: 'Win rate', value: '${s['win_rate'] ?? 0}%',
                  icon: Icons.military_tech, color: AppColors.green),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _StatCard(label: 'Avg finish', value: '${s['avg_finish'] ?? '—'}',
                  icon: Icons.trending_up, color: AppColors.cyan),
              _StatCard(label: 'Avg inc.', value: '${s['avg_incidents'] ?? '—'}',
                  icon: Icons.warning_amber, color: AppColors.red),
              _StatCard(label: 'BOW ⭐', value: '${s['best_of_week'] ?? 0}',
                  icon: Icons.star, color: AppColors.gold),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _StatCard(label: 'Tend. rating (5)', value: _signed(s['rating_trend_5']),
                  icon: Icons.show_chart, color: (s['rating_trend_5'] ?? 0) >= 0 ? AppColors.green : AppColors.red),
              _StatCard(label: 'Tend. SR (5)', value: _signed(s['sr_trend_5']),
                  icon: Icons.security, color: (s['sr_trend_5'] ?? 0) >= 0 ? AppColors.green : AppColors.red),
              _StatCard(label: 'Mejor puesto', value: '${s['best_finish'] ?? '—'}',
                  icon: Icons.workspace_premium, color: AppColors.cyan),
            ]),
          ),

          // Botones de análisis
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          // Últimas carreras
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(children: [
              Text('Últimas carreras',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.textDim),
                visualDensity: VisualDensity.compact,
                onPressed: () => _push('/analysis/races'),
              ),
            ]),
          ),
          ...lastRaces.map<Widget>((r) => _RaceTile(
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

  String _signed(dynamic v) {
    if (v == null) return '—';
    final n = (v as num).toDouble();
    return n > 0 ? '+$n' : '$n';
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62, height: 62,
      color: AppColors.surfaceAlt,
      child: const Icon(Icons.person, color: AppColors.textDim, size: 34),
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

class _StatCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.surface, AppColors.surfaceAlt.withValues(alpha: 0.55)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
        ]),
      ),
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
