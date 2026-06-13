import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const ConnectNetApp());
}

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

  void _login() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _logout() {
    setState(() {
      _isLoggedIn = false;
      _currentIndex = 0;
    });
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

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentIndex == 0
            ? const DashboardScreen(key: ValueKey('DashboardPage'))
            : ProfileScreen(key: const ValueKey('ProfilePage'), onLogout: _logout),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF0F1419),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
