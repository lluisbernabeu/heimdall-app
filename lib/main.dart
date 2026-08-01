import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/api_client.dart';
import 'screens/login_screen.dart';
import 'screens/link_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/progression_screen.dart';
import 'screens/sectors_screen.dart';
import 'screens/consistency_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/compare_screen.dart';

void main() => runApp(const HeimdallApp());

class HeimdallApp extends StatelessWidget {
  const HeimdallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heimdall',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/link': (_) => const LinkScreen(),
        '/loading': (_) => LoadingScreen(
            profileId: ModalRoute.of(context)!.settings.arguments as int),
        '/home': (_) => const HomeScreen(),
        '/analysis/progression': (_) => const ProgressionScreen(),
        '/analysis/sectors': (_) => const SectorsScreen(),
        '/analysis/consistency': (_) => const ConsistencyScreen(),
        '/analysis/incidents': (_) => const IncidentsScreen(),
        '/analysis/compare': (_) => const CompareScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final token = await ApiClient.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    try {
      await ApiClient.post('/api/auth/verify');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      await ApiClient.clearToken();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          HeimdallLogo(size: 96),
          SizedBox(height: 24),
          Text('HEIMDALL',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                  letterSpacing: 8, color: AppColors.text)),
          SizedBox(height: 8),
          Text('Analítica de Low Fuel Motorsport',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        ]),
      ),
    );
  }
}
