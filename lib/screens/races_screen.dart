import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'race_detail_screen.dart';

/// Lista completa de carreras del piloto.
class RacesScreen extends StatefulWidget {
  final int profileId;
  const RacesScreen({super.key, required this.profileId});
  @override
  State<RacesScreen> createState() => _RacesScreenState();
}

class _RacesScreenState extends State<RacesScreen> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Carreras')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.gold,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 30),
                    itemCount: _races!.length,
                    itemBuilder: (context, i) => _RaceCard(
                      r: _races![i],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RaceDetailScreen(
                              profileId: widget.profileId,
                              raceId: _races![i]['id'] as int))),
                    ),
                  ),
                ),
    );
  }
}

class _RaceCard extends StatelessWidget {
  final Map<String, dynamic> r; final VoidCallback onTap;
  const _RaceCard({required this.r, required this.onTap});
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
              Text('${r['event_name']} · ${fmtDate(r['race_date'])}',
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
