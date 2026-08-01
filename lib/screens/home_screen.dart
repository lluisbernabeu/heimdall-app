import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/race_card.dart';
import 'loading_screen.dart';
import 'race_detail_screen.dart';

/// Home: 3 pestañas — Resumen (insight), Análisis (herramientas), Carreras.
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
  int _tab = 0;

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
            icon: const Icon(Icons.sync, color: AppColors.cyan, size: 32),
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
            icon: const Icon(Icons.logout, color: AppColors.textDim, size: 32),
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
              : IndexedStack(
                  index: _tab,
                  children: [
                    _SummaryTab(data: _data!, insight: _insight, onRefresh: _load),
                    _AnalysisTab(data: _data!, onPush: _push),
                    _RacesTab(profileId: _profileId!),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.gold.withValues(alpha: 0.22),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined, color: AppColors.textDim, size: 32),
            selectedIcon: Icon(Icons.insights, color: AppColors.gold, size: 34),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined, color: AppColors.textDim, size: 32),
            selectedIcon: Icon(Icons.analytics, color: AppColors.gold, size: 34),
            label: 'Análisis',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined, color: AppColors.textDim, size: 32),
            selectedIcon: Icon(Icons.flag, color: AppColors.gold, size: 34),
            label: 'Carreras',
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

// =====================================================================
// PESTAÑA 1 — RESUMEN: veredicto + señales + qué hacer
// =====================================================================
class _SummaryTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? insight;
  final Future<void> Function() onRefresh;
  const _SummaryTab({required this.data, required this.insight, required this.onRefresh});

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

  @override
  Widget build(BuildContext context) {
    final p = (data['profile'] as Map? ?? {});
    final verdict = (insight?['verdict'] as Map? ?? {});
    final insights = (insight?['insights'] as List? ?? []);
    final action = (insight?['action'] as Map? ?? {});
    final vColor = _toneColor(verdict['tone']?.toString() ?? 'cyan');

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Cabecera piloto
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

          // Veredicto
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [vColor.withValues(alpha: 0.22), AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: vColor.withValues(alpha: 0.55), width: 1.2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${verdict['emoji'] ?? '📊'}', style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${verdict['title'] ?? 'Estado'}',
                      style: TextStyle(color: vColor, fontSize: 22, fontWeight: FontWeight.w900,
                          letterSpacing: 0.3)),
                ),
              ]),
              const SizedBox(height: 10),
              Text('${verdict['msg'] ?? ''}',
                  style: const TextStyle(color: AppColors.text, fontSize: 14.5, height: 1.4)),
            ]),
          ),

          // Señales
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

          // Qué hacer ahora
          if (action.isNotEmpty)
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

          // Glosario (¿qué significa cada cosa?)
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceAlt),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: const Icon(Icons.menu_book_outlined, color: AppColors.gold),
              title: const Text('¿Qué significa cada cosa?',
                  style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _GlossaryItem(
                    term: 'Rating (ELO)',
                    def: 'Tu nivel general. Sube al quedar por delante de pilotos con más rating que tú y baja al quedar por detrás de los que tienen menos. Empieza en 1500.'),
                _GlossaryItem(
                    term: 'SR (Safety Rating)',
                    def: 'Tu nota de seguridad. Sube con carreras limpias (pocos incidentes) y baja con choques, salidas de pista y sanciones. Determina tu licencia.'),
                _GlossaryItem(
                    term: 'Incidentes',
                    def: 'Lo que LFM registra: C = cut (cortaste la pista y la vuelta no cuenta), D = contacto/daño, O = fuera de pista, R = relaunch (te reiniciaste en la pista). Menos es siempre mejor.'),
                _GlossaryItem(
                    term: 'Split',
                    def: 'Grupo de pilotos de nivel parecido en una misma carrera. Los splits se numeran: split 1 = los más rápidos.'),
                _GlossaryItem(
                    term: 'Sectores S1/S2/S3',
                    def: 'El circuito se divide en 3 tramos. Tu vuelta perfecta es la suma de tu mejor S1 + S2 + S3. Ahí se gana o se pierde el tiempo.'),
                _GlossaryItem(
                    term: 'SOF (Strength of Field)',
                    def: 'El rating medio de los pilotos de tu carrera. Ganar en un SOF alto da más puntos y rating.'),
                _GlossaryItem(
                    term: 'Best of Week (BOW)',
                    def: 'Tu mejor resultado de la semana según LFM. Llevas 4 ⭐ — buen ritmo cuando todo sale limpio.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlossaryItem extends StatelessWidget {
  final String term; final String def;
  const _GlossaryItem({required this.term, required this.def});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(term, style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(def, style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.35)),
      ]),
    );
  }
}

// =====================================================================
// PESTAÑA 2 — ANÁLISIS: herramientas
// =====================================================================
class _AnalysisTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(String) onPush;
  const _AnalysisTab({required this.data, required this.onPush});

  @override
  Widget build(BuildContext context) {
    final s = (data['stats'] as Map? ?? {});
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Herramientas de análisis',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 4),
        const Text('Métricas en detalle: ritmo, consistencia y seguridad.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 14),
        _ActionRow(icon: Icons.show_chart, label: 'Progresión',
            sub: 'Evolución de tu rating y SR carrera a carrera',
            onTap: () => onPush('/analysis/progression')),
        _ActionRow(icon: Icons.timer_outlined, label: 'Sectores',
            sub: 'Dónde ganas y pierdes tiempo en cada vuelta',
            onTap: () => onPush('/analysis/sectors')),
        _ActionRow(icon: Icons.speed, label: 'Consistencia',
            sub: 'Estabilidad de tus tiempos entre vueltas',
            onTap: () => onPush('/analysis/consistency')),
        _ActionRow(icon: Icons.report, label: 'Incidentes',
            sub: 'Cuándo y cómo pierdes la concentración',
            onTap: () => onPush('/analysis/incidents')),
        _ActionRow(icon: Icons.compare_arrows, label: 'Comparar',
            sub: 'Tu perfil frente a cualquier piloto del sistema',
            onTap: () => onPush('/analysis/compare')),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceAlt),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Números rápidos',
                style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _MiniStat('${s['races'] ?? 0}', 'carreras'),
              _MiniStat('${s['podiums'] ?? 0}', 'podios'),
              _MiniStat('${s['avg_finish'] ?? '—'}', 'avg finish'),
              _MiniStat('${s['avg_incidents'] ?? '—'}', 'avg inc.'),
              _MiniStat('${s['best_of_week'] ?? 0}', 'BOW ⭐'),
              _MiniStat('${s['best_finish'] ?? '—'}', 'mejor puesto'),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value; final String label;
  const _MiniStat(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      ]),
    );
  }
}

// =====================================================================
// PESTAÑA 3 — CARRERAS
// =====================================================================
class _RacesTab extends StatefulWidget {
  final int profileId;
  const _RacesTab({required this.profileId});
  @override
  State<_RacesTab> createState() => _RacesTabState();
}

class _RacesTabState extends State<_RacesTab> {
  List<Map<String, dynamic>>? _races;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('/api/profile/${widget.profileId}/races');
      final list = (data as List).cast<Map>();
      setState(() {
        _races = [for (final r in list) Map<String, dynamic>.from(r)];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)));
    final races = _races!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: races.length,
        itemBuilder: (context, i) => RaceCard(
          r: races[i],
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RaceDetailScreen(
                  profileId: widget.profileId, raceId: races[i]['id'] as int))),
        ),
      ),
    );
  }
}

// =====================================================================
// Widgets compartidos
// =====================================================================
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
  final IconData icon; final String label; final VoidCallback onTap; final String? sub;
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.sub});
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: AppColors.text, fontSize: 14,
                  fontWeight: FontWeight.w600)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub!, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
              ],
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textDim, size: 20),
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
