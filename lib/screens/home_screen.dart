import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/race_card.dart';
import '../widgets/feature_search.dart';
import 'loading_screen.dart';
import 'race_detail_screen.dart';
import 'schedule_screen.dart';
import 'home_dashboard.dart';

/// Home: 5 pestañas — Inicio (dashboard con datos vivos), Calendario
/// (acción), Carreras (resultado), Análisis (mejora), Perfil (estado).
/// Swipe horizontal entre pestañas para navegación fluida.
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

  static const List<String> _tabTitles = [
    'Inicio', 'Calendario', 'Carreras', 'Análisis', 'Perfil',
  ];

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
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Heimdall'),
            Text(
              _tabTitles[_tab],
              style: const TextStyle(color: AppColors.textDim, fontSize: 10.5,
                  fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
          ]),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.gold, size: 30),
            tooltip: 'Buscar',
            onPressed: () => showFeatureSearch(context, (i) => setState(() => _tab = i)),
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: AppColors.gold, size: 32),
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
              : RuneBackground(
                  // Swipe horizontal entre pestañas (navegación fluida)
                  child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (v.abs() < 300) return;
                    final next = _tab + (v < 0 ? 1 : -1);
                    if (next >= 0 && next < 5) setState(() => _tab = next);
                  },
                  child: IndexedStack(
                  index: _tab,
                  children: [
                    // 0. Inicio — dashboard con tus datos vivos, cada
                    // tarjeta es una puerta a la herramienta que la explica
                    HomeDashboardScreen(
                      profileId: _profileId!,
                      data: _data!,
                      insight: _insight,
                      onGoToTab: (i) => setState(() => _tab = i),
                    ),
                    // 1. Calendario — la acción: ¿cuándo corro y puedo correr?
                    ScheduleScreen(profileId: _profileId),
                    // 2. Carreras — el resultado: historial completo
                    _RacesTab(profileId: _profileId!),
                    // 3. Análisis — la mejora: diagnóstico + herramientas
                    _AnalysisTab(data: _data!, insight: _insight, onPush: _push),
                    // 4. Perfil — el estado: veredicto + cifras + tendencia
                    _SummaryTab(data: _data!, insight: _insight, onRefresh: _load),
                  ],
                ))),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.gold.withValues(alpha: 0.22),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.textDim, size: 28),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.gold, size: 30),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.today_outlined, color: AppColors.textDim, size: 28),
            selectedIcon: Icon(Icons.today, color: AppColors.gold, size: 30),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined, color: AppColors.textDim, size: 28),
            selectedIcon: Icon(Icons.flag, color: AppColors.gold, size: 30),
            label: 'Carreras',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined, color: AppColors.textDim, size: 28),
            selectedIcon: Icon(Icons.analytics, color: AppColors.gold, size: 30),
            label: 'Análisis',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.textDim, size: 28),
            selectedIcon: Icon(Icons.person, color: AppColors.gold, size: 30),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  void _push(String route) {
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
      default: return AppColors.gold;
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
                colors: [AppColors.surfaceAlt, AppColors.bg],
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
                    _Badge(text: p['license']?.toString() ?? '—', color: AppColors.gold),
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

          // Cifras clave (resumen rápido, sin duplicar Análisis)
          _SummaryStats(stats: Map<String, dynamic>.from(data['stats'] as Map? ?? {})),

          // Percentil global de SR (¿mejor que qué % de LFM?)
          _SrPercentileCard(profileId: data['profile_id'] as int?),

          // Qué hacer ahora
          if (action.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.surfaceAlt, AppColors.bg],
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
                      color: AppColors.bg, size: 22),
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

          // Tendencia rating/SR
          _TrendStrip(stats: Map<String, dynamic>.from(data['stats'] as Map? ?? {})),

          // Acceso rápido: Clasificación + Logros
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              Expanded(
                child: _ProfileActionCard(
                  icon: Icons.emoji_events_rounded,
                  label: 'Clasificación',
                  sub: 'Tu posición en el campeonato',
                  onTap: () => Navigator.of(context).pushNamed('/profile/standings'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileActionCard(
                  icon: Icons.military_tech_rounded,
                  label: 'Logros',
                  sub: 'Progreso y rating por sim',
                  onTap: () => Navigator.of(context).pushNamed('/profile/achievements'),
                ),
              ),
            ]),
          ),

          // Glosario (¿qué significa cada cosa?) — pantalla propia, 1 tap
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ActionRow(
              icon: Icons.menu_book_outlined,
              label: '¿Qué significa cada cosa?',
              sub: 'Rating, SR, splits, incidentes, SOF… el glosario completo',
              onTap: () => Navigator.of(context).pushNamed('/glossary'),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// PESTAÑA 2 — ANÁLISIS: diagnóstico + herramientas
// =====================================================================
class _AnalysisTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? insight;
  final void Function(String) onPush;
  const _AnalysisTab({required this.data, required this.insight, required this.onPush});

  Color _toneColor(String tone) {
    switch (tone) {
      case 'red': return AppColors.red;
      case 'orange': return AppColors.gold;
      case 'green': return AppColors.green;
      default: return AppColors.gold;
    }
  }

  IconData _toneIcon(String icon) {
    switch (icon) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'sector': return Icons.timer_outlined;
      case 'trophy': return Icons.emoji_events_outlined;
      case 'shield': return Icons.verified_user_outlined;
      default: return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insights = (insight?['insights'] as List? ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Diagnóstico: la señal más importante primero ----
        const Text('Diagnóstico',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 4),
        const Text('Esto es lo que más te está costando ahora mismo.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 12),
        if (insights.isNotEmpty) ...[
          _PriorityCard(
            icon: _toneIcon((insights.first as Map)['icon']?.toString() ?? ''),
            color: _toneColor((insights.first as Map)['tone']?.toString() ?? 'cyan'),
            title: (insights.first as Map)['title']?.toString() ?? '',
            msg: (insights.first as Map)['msg']?.toString() ?? '',
          ),
          if (insights.length > 1) ...[
            const SizedBox(height: 10),
            ...insights.skip(1).map<Widget>((raw) {
              final i = Map<String, dynamic>.from(raw as Map);
              final c = _toneColor(i['tone']?.toString() ?? 'cyan');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(_toneIcon(i['icon']?.toString() ?? ''), color: c, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i['title']?.toString() ?? '',
                        style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(i['msg']?.toString() ?? '',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11.5, height: 1.35)),
                  ])),
                ]),
              );
            }),
          ],
          const SizedBox(height: 18),
        ],
        // ---- Herramientas: cada una responde una pregunta ----
        const Text('Analizar a fondo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 4),
        const Text('Entra en una herramienta para ver el detalle y qué mejorar en pista.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 12),
        _ActionRow(icon: Icons.timer_outlined, label: 'Sectores',
            sub: '¿Dónde pierdes el tiempo? Tus S1/S2/S3 vs el más rápido del split',
            onTap: () => onPush('/analysis/sectors')),
        _ActionRow(icon: Icons.map_outlined, label: 'Circuito',
            sub: '¿Cómo estás en cada trazado? Tu vuelta vs el récord, con mapa por sectores',
            onTap: () => onPush('/analysis/circuit')),
        _ActionRow(icon: Icons.speed, label: 'Consistencia',
            sub: '¿Qué tan regulares son tus vueltas? Dónde se te va la constancia',
            onTap: () => onPush('/analysis/consistency')),
        _ActionRow(icon: Icons.report, label: 'Incidentes',
            sub: '¿En qué te estrellas? Cuándo y cómo pierdes el control',
            onTap: () => onPush('/analysis/incidents')),
        _ActionRow(icon: Icons.show_chart, label: 'Progresión',
            sub: '¿Vas a mejor o a peor? Evolución de tu rating y SR',
            onTap: () => onPush('/analysis/progression')),
        _ActionRow(icon: Icons.compare_arrows, label: 'Comparar',
            sub: '¿Cómo estás frente a otros pilotos? Perfil vs perfil',
            onTap: () => onPush('/analysis/compare')),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Tarjeta de prioridad — la señal nº1 del diagnóstico, grande y clara.
class _PriorityCard extends StatelessWidget {
  final IconData icon; final Color color; final String title; final String msg;
  const _PriorityCard({required this.icon, required this.color, required this.title, required this.msg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.16), AppColors.surface],
          stops: const [0.0, 0.65],
        ),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PRIORIDAD', style: TextStyle(color: AppColors.textDim, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 3),
          Text(title, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(msg, style: const TextStyle(color: AppColors.text, fontSize: 12.5, height: 1.4)),
        ])),
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

class _SummaryStats extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _SummaryStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, Color)>[
      ('${stats['races'] ?? 0}', 'carreras', AppColors.gold),
      ('${stats['podiums'] ?? 0}', 'podios', AppColors.gold),
      ('${stats['podium_rate'] ?? 0}%', 'en podio', AppColors.green),
      ('${stats['avg_incidents'] ?? '—'}', 'inc/carrera', AppColors.red),
      ('${stats['best_of_week'] ?? 0}', '⭐ BOW', AppColors.gold),
      ('#${stats['avg_finish'] ?? '—'}', 'finish med', AppColors.text),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tus cifras',
            style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          for (final (v, l, c) in items.take(3))
            Expanded(child: _StatCell(v, l, c)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final (v, l, c) in items.skip(3))
            Expanded(child: _StatCell(v, l, c)),
        ]),
      ]),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value; final String label; final Color color;
  const _StatCell(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 9.5)),
    ]);
  }
}

class _TrendStrip extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _TrendStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rt = stats['rating_trend_5'];
    final st = stats['sr_trend_5'];
    if (rt == null && st == null) return const SizedBox.shrink();
    final rUp = (rt as num).toDouble() >= 0;
    final sUp = (st as num).toDouble() >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Row(children: [
        Icon(rUp ? Icons.trending_up : Icons.trending_down,
            color: rUp ? AppColors.green : AppColors.red, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Rating ${rUp ? '+' : ''}$rt pts · SR ${sUp ? '+' : ''}$st en las últimas 5 carreras',
            style: const TextStyle(color: AppColors.text, fontSize: 12.5),
          ),
        ),
        Icon(sUp ? Icons.arrow_upward : Icons.arrow_downward,
            color: sUp ? AppColors.green : AppColors.red, size: 18),
      ]),
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
              color: AppColors.gold.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.gold, size: 17),
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

/// Tarjeta de acceso rápido del Perfil (Clasificación / Logros).
class _ProfileActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _ProfileActionCard(
      {required this.icon, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.surfaceAlt, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.goldLight, AppColors.gold],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.bg, size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11), maxLines: 2),
          ]),
        ),
      ),
    );
  }
}


/// Tarjeta de percentil global de SR: ¿mejor que qué % de la comunidad?
/// Carga ligera (endpoint cacheado 24h en BD) — falla silencioso.
class _SrPercentileCard extends StatefulWidget {
  final int? profileId;
  const _SrPercentileCard({this.profileId});
  @override
  State<_SrPercentileCard> createState() => _SrPercentileCardState();
}

class _SrPercentileCardState extends State<_SrPercentileCard> {
  Map<String, dynamic>? _data;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.profileId;
    if (pid == null) {
      setState(() => _done = true);
      return;
    }
    try {
      final d = await ApiClient.get('/api/global/sr-percentile/$pid');
      if (!mounted) return;
      setState(() { _data = Map<String, dynamic>.from(d as Map); _done = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_done || _data == null) return const SizedBox.shrink();
    final pct = (_data?['percentile'] as Map?);
    if (pct == null) return const SizedBox.shrink();
    final betterThan = (pct['better_than_pct'] as num?)?.toStringAsFixed(1);
    final avg = (_data?['distribution'] as Map?)?['average_sr'] as num?;
    final overall = (_data?['distribution'] as Map?)?['overall'] as num?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlt, AppColors.bg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.goldLight, AppColors.gold],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.public_rounded, color: AppColors.bg, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TU SR EN LA COMUNIDAD',
                style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('Mejor que el $betterThan% de LFM',
                style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(avg != null && overall != null
                ? 'Media global ${avg.toStringAsFixed(2)} · $overall pilotos'
                : 'Distribución global de Safety Rating',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}
