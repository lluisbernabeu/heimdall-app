import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Pantalla de "cargando tus carreras" — poll del estado de sync.
class LoadingScreen extends StatefulWidget {
  final int profileId;
  const LoadingScreen({super.key, required this.profileId});
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Timer? _timer;
  String _phase = 'Iniciando...';
  String _msg = 'Conectando con LFM...';
  double _progress = 0.02;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final st = await ApiClient.get('/api/profile/${widget.profileId}/sync/status');
      if (!mounted) return;
      final status = st['status'] as String? ?? 'pending';
      final total = (st['total_steps'] as num?)?.toDouble() ?? 1;
      final done = (st['done_steps'] as num?)?.toDouble() ?? 0;
      setState(() {
        _phase = (st['phase'] as String?) ?? '';
        _msg = (st['current_msg'] as String?) ?? '';
        _progress = (total > 0 ? done / total : 0.0).clamp(0.0, 1.0).toDouble();
        if (status == 'done') {
          _done = true;
          _timer?.cancel();
          _msg = '¡Datos listos!';
        } else if (status == 'error') {
          _error = st['last_error'] as String? ?? 'Error de sincronización';
          _timer?.cancel();
        }
      });
      if (_done || _error != null) {
        _timer?.cancel();
        if (_done) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      }
    } catch (_) {
      // el poll puede fallar momentáneamente; reintenta
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bg, AppColors.bg],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HeimdallLogo(size: 72),
                const SizedBox(height: 28),
                Text('Descargando tus carreras',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 8),
                Text(_msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 14)),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    backgroundColor: AppColors.surfaceAlt,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.gold, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text(_phase,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
