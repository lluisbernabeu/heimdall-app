import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Vincular cuenta LFM: pegar ID o URL del perfil.
class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key});
  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _link() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Pega tu ID de LFM o la URL de tu perfil');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final body = RegExp(r'^\d+$').hasMatch(input)
          ? {'lfm_user_id': int.parse(input)}
          : {'url': input};
      final res = await ApiClient.post('/api/profile/link-url', body: body);
      final profileId = res['id'] as int;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/loading', arguments: profileId);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular LFM')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HeimdallLogo(size: 56),
            const SizedBox(height: 20),
            const Text('Conecta tu cuenta de Low Fuel Motorsport',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            const Text(
              'Abre tu perfil en lowfuelmotorsport.com y copia el ID '
              '(el número de la URL, p. ej. /profile/310195) o pega la URL completa.',
              style: TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'ID o URL del perfil de LFM',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _link,
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0A1420)))
                  : const Text('Conectar y descargar mis carreras'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
              child: const Text('Ya tengo un perfil vinculado'),
            ),
          ],
        ),
      ),
    );
  }
}
