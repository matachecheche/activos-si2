import 'package:flutter/material.dart';
import '../models/json_util.dart';
import '../services/auth_service.dart';
import '../services/plataforma_service.dart';
import '../widgets/comunes.dart';

/// HU-11: alta publica y autoservicio de una empresa con su administrador,
/// plan. El alta incluye 15 días de prueba; el cobro real se hace después con
/// Mercado Pago o PayPal desde la pantalla de suscripción. No requiere sesion.
class RegistroEmpresaScreen extends StatefulWidget {
  const RegistroEmpresaScreen({super.key});

  @override
  State<RegistroEmpresaScreen> createState() => _RegistroEmpresaScreenState();
}

class _RegistroEmpresaScreenState extends State<RegistroEmpresaScreen> {
  final PlataformaService _servicio = PlataformaService();
  final _form = GlobalKey<FormState>();
  final _nombreEmpresa = TextEditingController();
  final _nit = TextEditingController();
  final _rubro = TextEditingController();
  final _correoContacto = TextEditingController();
  final _nombreAdmin = TextEditingController();
  final _correoAdmin = TextEditingController();
  final _passwordAdmin = TextEditingController();

  List<dynamic> _planes = [];
  int? _planId;
  String _metodoPago = 'MERCADO_PAGO';
  bool _ocupado = false;
  String? _aviso;
  /// Sprint 3 / multiempresa: si ya hay sesion, la empresa se agrega a la cuenta
  /// del usuario (no pide contrasena ni correo).
  bool _sesionActiva = false;

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _sesionActiva = auth.isLoggedIn();
    if (_sesionActiva) {
      _correoAdmin.text = auth.correo;
      _nombreAdmin.text = auth.nombre;
      if (_correoContacto.text.isEmpty) _correoContacto.text = auth.correo;
    }
    _cargarPlanes();
  }

  @override
  void dispose() {
    for (final c in [_nombreEmpresa, _nit, _rubro, _correoContacto, _nombreAdmin, _correoAdmin, _passwordAdmin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarPlanes() async {
    try {
      final planes = await _servicio.planes();
      if (!mounted) return;
      setState(() {
        _planes = planes.where((p) => mapa(p)['activo'] != false).toList();
        if (_planes.isNotEmpty) _planId = entero(mapa(_planes.first)['id']);
      });
    } catch (e) {
      setState(() => _aviso = 'No se pudieron cargar los planes: $e');
    }
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    if (_planId == null) {
      setState(() => _aviso = 'Selecciona un plan.');
      return;
    }
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      if (_sesionActiva) {
        await _agregarAMiCuenta();
        return;
      }
      final r = await _servicio.registrarEmpresa({
        'nombreEmpresa': _nombreEmpresa.text.trim(),
        'nit': _nit.text.trim(),
        'rubro': _rubro.text.trim(),
        'correoContacto': _correoContacto.text.trim(),
        'planId': _planId,
        'nombreAdmin': _nombreAdmin.text.trim(),
        'correoAdmin': _correoAdmin.text.trim(),
        'passwordAdmin': _passwordAdmin.text,
        'metodoPago': _metodoPago,
        'meses': 1,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Empresa registrada'),
          content: Text(
            'La empresa "${r['nombreEmpresa'] ?? _nombreEmpresa.text.trim()}" fue creada con el plan '
            '${r['plan'] ?? ''} en modo prueba (15 días).\n\n'
            'Ya puedes iniciar sesión con ${_correoAdmin.text.trim()}. '
            'Para renovar, entra en "Mi suscripción" y paga con Mercado Pago o PayPal.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
              child: const Text('Ir al inicio de sesión'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _aviso = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Agrega la empresa a la cuenta ya autenticada y abre esa empresa.
  Future<void> _agregarAMiCuenta() async {
    final auth = AuthService();
    final id = await auth.agregarEmpresa(
      nombreEmpresa: _nombreEmpresa.text.trim(),
      correoContacto: _correoContacto.text.trim(),
      planId: _planId!,
      nit: _nit.text.trim(),
      rubro: _rubro.text.trim(),
    );
    if (!mounted) return;
    if (id == null) {
      setState(() => _aviso = auth.ultimoError);
      return;
    }
    final error = await auth.cambiarEmpresa(id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _aviso = error);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Empresa agregada'),
        content: Text(
          'La empresa "${_nombreEmpresa.text.trim()}" fue creada con 15 dias de prueba y ya es la '
          'empresa activa. Para renovarla, entra en "Mi suscripcion" y paga con Mercado Pago o PayPal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barra(_sesionActiva ? 'Agregar empresa' : 'Registrar mi empresa'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Datos de la empresa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nombreEmpresa,
                decoration: decoracion('Nombre de la empresa'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _nit, decoration: decoracion('NIT')),
              const SizedBox(height: 10),
              TextFormField(controller: _rubro, decoration: decoracion('Rubro o actividad')),
              const SizedBox(height: 10),
              TextFormField(
                controller: _correoContacto,
                keyboardType: TextInputType.emailAddress,
                decoration: decoracion('Correo de contacto'),
                validator: (v) => (v != null && v.isNotEmpty && !v.contains('@')) ? 'Correo no válido' : null,
              ),
              const SizedBox(height: 20),
              const Text('Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              if (_planes.isEmpty)
                const Text('Cargando planes...', style: estiloMuted)
              else
                RadioGroup<int>(
                  groupValue: _planId,
                  onChanged: (v) => setState(() => _planId = v),
                  child: Column(
                    children: _planes.map((p) {
                      final m = mapa(p);
                      return RadioListTile<int>(
                        value: entero(m['id']),
                        title: Text(texto(m['nombre'])),
                        subtitle: Text(
                          'Bs ${numero(m['precioMensual']).toStringAsFixed(0)}/mes · '
                          '${m['maxUsuarios'] ?? '∞'} usuarios · ${m['maxActivos'] ?? '∞'} activos',
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              if (!_sesionActiva) ...[
                const Text('Administrador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nombreAdmin,
                  decoration: decoracion('Nombre completo del administrador'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _correoAdmin,
                  keyboardType: TextInputType.emailAddress,
                  decoration: decoracion('Correo del administrador'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Correo no válido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordAdmin,
                  obscureText: true,
                  decoration: decoracion('Contraseña', sugerencia: 'Mínimo 8 caracteres'),
                  validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                ),
              ] else ...[
                const Text('Se usara tu cuenta actual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text('La empresa nueva quedara a nombre de $_correoAdmin.',
                    style: estiloMuted),
              ],
              const SizedBox(height: 20),
              const Text('Cómo vas a pagar la renovación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'MERCADO_PAGO', label: Text('Mercado Pago')),
                  ButtonSegment(value: 'PAYPAL', label: Text('PayPal')),
                ],
                selected: {_metodoPago},
                onSelectionChanged: (s) => setState(() => _metodoPago = s.first),
              ),
              if (_aviso != null) ...[
                const SizedBox(height: 14),
                Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _ocupado ? null : _registrar,
                child: Text(_ocupado ? 'Registrando...' : 'Crear empresa y cuenta'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
