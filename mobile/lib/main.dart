import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/activos_screen.dart';

void main() {
  runApp(const ActivosFijosApp());
}

class ActivosFijosApp extends StatelessWidget {
  const ActivosFijosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activos Fijos y Presupuestos',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const _ArrancarApp(),
    );
  }
}

class _ArrancarApp extends StatelessWidget {
  const _ArrancarApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const ActivosScreen() : const LoginScreen();
      },
    );
  }
}
