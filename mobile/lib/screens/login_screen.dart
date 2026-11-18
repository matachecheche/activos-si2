import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';
import 'registro_empresa_screen.dart';

/// Usuarios de prueba sembrados en la base (database/fix_usuarios_prueba.sql). Solo para pruebas:
/// poner en false antes de un entorno real.
const bool mostrarUsuariosPrueba = true;

class _UsuarioPrueba {
  final String rol;
  final String correo;
  final String password;

  const _UsuarioPrueba(this.rol, this.correo, this.password);
}

const List<_UsuarioPrueba> _cuentasPrueba = [
  _UsuarioPrueba('ADMINISTRADOR', 'admin@uagrm.edu.bo', 'admin123'),
  _UsuarioPrueba('ENCARGADO_ACTIVOS', 'encargado@uagrm.edu.bo', 'encargado123'),
  _UsuarioPrueba('CONTADOR', 'contador@uagrm.edu.bo', 'contador123'),
  _UsuarioPrueba('RESPONSABLE_FINANCIERO', 'financiero@uagrm.edu.bo', 'financiero123'),
  // Super Admin de la plataforma (HU-12): administra todas las empresas.
  _UsuarioPrueba('SUPER_ADMIN', 'superadmin@plataforma.local', 'Cambiar123!'),
];

/// HU-01: inicio de sesion con bloqueo temporal tras varios intentos fallidos.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  String _error = '';
  String? _aviso;
  bool _bloqueado = false;
  String _correoBloqueado = '';
  bool _enviando = false;
  bool _verPassword = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _aviso = AuthService.avisoLogin;
    AuthService.avisoLogin = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _cambioCorreo(String correo) {
    if (_bloqueado && correo.trim().toLowerCase() != _correoBloqueado) {
      _timer?.cancel();
      setState(() {
        _bloqueado = false;
        _error = '';
      });
    }
  }

  void _usarUsuario(_UsuarioPrueba u) {
    _correoCtrl.text = u.correo;
    _passwordCtrl.text = u.password;
    _cambioCorreo(u.correo);
    setState(() => _error = _bloqueado ? _error : '');
  }

  Future<void> _ingresar() async {
    if (_bloqueado || _enviando) return;
    final correo = _correoCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (correo.isEmpty || password.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y tu contraseña.');
      return;
    }
    setState(() {
      _error = '';
      _aviso = null;
      _enviando = true;
    });
    final error = await _auth.login(correo, password);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => pantallaInicial()),
        (ruta) => false,
      );
      return;
    }
    setState(() {
      _enviando = false;
      _error = error;
    });
    if (RegExp('bloquead', caseSensitive: false).hasMatch(error)) {
      _iniciarCuentaRegresiva(error);
    }
  }

  void _iniciarCuentaRegresiva(String mensaje) {
    final coincidencia = RegExp(r'(\d+)\s*segundos?', caseSensitive: false).firstMatch(mensaje);
    final total = coincidencia != null ? int.parse(coincidencia.group(1)!) : 30;
    final fin = DateTime.now().add(Duration(seconds: total));
    _correoBloqueado = _correoCtrl.text.trim().toLowerCase();
    _timer?.cancel();
    setState(() => _bloqueado = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final restantes = (fin.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      if (restantes <= 0) {
        t.cancel();
        setState(() {
          _bloqueado = false;
          _error = 'Ya puedes volver a intentarlo.';
        });
      } else {
        setState(() => _error = 'Cuenta bloqueada. Intenta nuevamente en $restantes segundos.');
      }
    });
  }

  Widget _marca() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF1769E0), borderRadius: BorderRadius.circular(10)),
          child: const Text('AF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activos Fijos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorTexto)),
            Text('Control y presupuesto', style: estiloMuted),
          ],
        ),
      ],
    );
  }

  Widget _formulario() {
    final etiquetaBoton = _bloqueado ? 'Cuenta bloqueada' : (_enviando ? 'Verificando...' : 'Ingresar al sistema');
    return Tarjeta(
      margen: EdgeInsets.zero,
      relleno: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ACCESO SEGURO',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0)),
          ),
          const SizedBox(height: 4),
          const Text('Bienvenido de nuevo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 4),
          const Text('Ingresa con tus credenciales institucionales.', style: estiloMuted),
          const SizedBox(height: 16),
          if (_aviso != null) BannerMensaje(_aviso!, tipo: TipoBanner.aviso),
          TextField(
            controller: _correoCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            onChanged: _cambioCorreo,
            decoration: decoracion('Correo institucional', sugerencia: 'nombre@uagrm.edu.bo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: !_verPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _ingresar(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _verPassword = !_verPassword),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_error.isNotEmpty) BannerMensaje(_error),
          FilledButton(
            onPressed: (_bloqueado || _enviando) ? null : _ingresar,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(etiquetaBoton)),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegistroEmpresaScreen()),
              );
            },
            child: const Text('¿No tienes cuenta? Registra tu empresa aquí'),
          ),
        ],
      ),
    );
  }

  Widget _usuariosPrueba() {
    return Tarjeta(
      margen: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Usuarios de prueba (Sprint 1)', style: TextStyle(fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 6),
          for (final u in _cuentasPrueba)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.rol, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1769E0))),
                        Text('${u.correo} / ${u.password}', style: estiloMuted),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => _usarUsuario(u), child: const Text('Usar')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _marca(),
                  const SizedBox(height: 22),
                  _formulario(),
                  if (mostrarUsuariosPrueba) _usuariosPrueba(),
                  const SizedBox(height: 14),
                  Text('Servidor: ${ApiConfig.baseUrl}', textAlign: TextAlign.center, style: estiloMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
