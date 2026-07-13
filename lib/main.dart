import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://cjxgqskachxnvnsmwiaa.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqeGdxc2thY2h4bnZuc213aWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzOTIzODYsImV4cCI6MjA5Njk2ODM4Nn0.RiKdksaNwRHBO07dx57DSUM2h_3MU9Z2q7mswHnR4lw',
  );
  runApp(const ConnectNetApp());
}

final supabase = Supabase.instance.client;

class ConnectNetApp extends StatelessWidget {
  const ConnectNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConnectNet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DA1F2),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F1419),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1419),
      ),
      home: const MainNavigationController(),
    );
  }
}

class MainNavigationController extends StatefulWidget {
  const MainNavigationController({super.key});

  @override
  State<MainNavigationController> createState() =>
      _MainNavigationControllerState();
}

class _MainNavigationControllerState extends State<MainNavigationController> {
  bool _isLoggedIn = false;
  int _currentIndex = 0;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = supabase.auth.currentSession != null;
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _isLoggedIn = data.session != null;
          if (!_isLoggedIn) {
            _currentIndex = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _login() {
    // Manejado automáticamente por el listener reactivo
  }

  void _logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      // Ignorar o registrar error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: LoginScreen(
          key: const ValueKey('LoginPage'),
          onLoginSuccess: _login,
        ),
      );
    }

    return DashboardScreen(
      key: const ValueKey('DashboardPage'),
      onLogout: _logout,
    );
  }
}
