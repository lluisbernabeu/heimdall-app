import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/race_card.dart';
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
                    itemBuilder: (context, i) => RaceCard(
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
