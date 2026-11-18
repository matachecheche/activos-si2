import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/navegacion.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().cargar();
  // Cuando la sesion vence (token expirado, respuesta 401 o 30 min sin actividad) se vuelve al login.
  AuthService.alExpirarSesion = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (ruta) => false,
    );
  };
  runApp(const ActivosFijosApp());
}

class ActivosFijosApp extends StatelessWidget {
  const ActivosFijosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activos Fijos SP3',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1769E0),
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      ),
      builder: (context, child) => _ControlSesion(child: child ?? const SizedBox.shrink()),
      home: AuthService().isLoggedIn() ? pantallaInicial() : const LoginScreen(),
    );
  }
}

/// Registra la actividad del usuario (cada toque reinicia los 30 minutos de inactividad)
/// y revisa la sesion al volver de segundo plano.
class _ControlSesion extends StatefulWidget {
  final Widget child;

  const _ControlSesion({required this.child});

  @override
  State<_ControlSesion> createState() => _ControlSesionState();
}

class _ControlSesionState extends State<_ControlSesion> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AuthService().revisarInactividad();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AuthService().registrarActividad(),
      child: widget.child,
    );
  }
}
