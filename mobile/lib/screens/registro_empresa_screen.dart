import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  /// Ronda 11: Stripe es el metodo por defecto (el que el usuario pidio).
  String _metodoPago = 'STRIPE';
  /// Metodos de pago realmente configurados en el servidor.
  List<Map<String, dynamic>> _metodos = [];
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
    await _cargarMetodosPago();
  }

  /// Ronda 11: metodos de pago disponibles (Stripe, QR, transferencia).
  Future<void> _cargarMetodosPago() async {
    try {
      final lista = await _servicio.metodosPago();
      if (!mounted) return;
      setState(() {
        _metodos = lista.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        // Si el metodo por defecto no esta configurado se elige el primero
        // que si lo este, para no ofrecer un cobro imposible.
        if (!_metodoDisponible(_metodoPago)) {
          final disponible = _metodos.where((m) => m['configurado'] == true).toList();
          if (disponible.isNotEmpty) _metodoPago = '${disponible.first['nombre']}';
        }
      });
    } catch (_) {
      // Si no se pueden leer, se ofrecen igual los metodos principales.
    }
  }

  bool _metodoDisponible(String nombre) {
    final m = _metodos.where((x) => x['nombre'] == nombre).toList();
    if (m.isEmpty) return true;
    return m.first['configurado'] == true;
  }

  String _mensajeMetodo(String nombre) {
    final m = _metodos.where((x) => x['nombre'] == nombre).toList();
    if (m.isEmpty) return '';
    if (m.first['configurado'] == true) return '';
    return texto(m.first['mensaje'], 'Este metodo no esta configurado en el servidor.');
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
      await _mostrarCobro(r, esRegistroPublico: true);
    } catch (e) {
      if (mounted) setState(() => _aviso = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Agrega la empresa a la cuenta ya autenticada y abre esa empresa.
  Future<void> _agregarAMiCuenta() async {
    final auth = AuthService();
    final respuesta = await auth.agregarEmpresaDetalle(
      nombreEmpresa: _nombreEmpresa.text.trim(),
      correoContacto: _correoContacto.text.trim(),
      planId: _planId!,
      nit: _nit.text.trim(),
      rubro: _rubro.text.trim(),
      metodoPago: _metodoPago,
    );
    if (!mounted) return;
    if (respuesta == null) {
      setState(() => _aviso = auth.ultimoError);
      return;
    }
    final id = entero(respuesta['empresaId']);
    final error = await auth.cambiarEmpresa(id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _aviso = error);
      return;
    }
    await _mostrarCobro(respuesta, esRegistroPublico: false);
  }

  /// Ronda 11: muestra el cobro abierto (Stripe, QR o transferencia) con los
  /// datos para pagar y el enlace a la pasarela.
  Future<void> _mostrarCobro(Map<String, dynamic> r, {required bool esRegistroPublico}) async {
    if (!mounted) return;
    final url = texto(r['checkoutUrl']);
    final qr = texto(r['qrImagen']);
    final banco = r['datosBancarios'] is Map ? Map<String, dynamic>.from(r['datosBancarios'] as Map) : null;
    final instrucciones = texto(r['instrucciones'], texto(r['mensajePago']));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Empresa creada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La empresa "${texto(r['nombreEmpresa'], _nombreEmpresa.text.trim())}" quedo creada con '
                '15 dias de prueba del plan ${texto(r['plan'])}.'
                '${esRegistroPublico ? ' Ya puedes iniciar sesion con ${_correoAdmin.text.trim()}.' : ''}',
              ),
              if (instrucciones.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(instrucciones, style: estiloMuted),
              ],
              if (url.isNotEmpty) ...[
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    final abierto = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    if (!abierto && dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Abre este enlace para pagar: $url')),
                      );
                    }
                  },
                  child: const Text('Pagar ahora'),
                ),
              ],
              if (qr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Escanea este codigo QR con la app de tu banco:', style: estiloMuted),
                const SizedBox(height: 6),
                Image.memory(base64Decode(qr.split(',').last), width: 190, height: 190),
              ],
              if (banco != null) ...[
                const SizedBox(height: 10),
                const Text('Datos para la transferencia:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Banco: ${texto(banco['banco'], '-')}'),
                Text('Cuenta: ${texto(banco['cuenta'], '-')}'),
                Text('Titular: ${texto(banco['titular'], '-')}'),
                Text('NIT/CI: ${texto(banco['nit'], '-')}'),
                Text('Sucursal: ${texto(banco['sucursal'], '-')}'),
                Text('Monto: Bs ${r['monto'] ?? '-'}'),
                Text('Referencia: ${texto(r['referenciaPago'], '-')}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).popUntil((ruta) => ruta.isFirst),
            child: Text(esRegistroPublico ? 'Ir al inicio de sesion' : 'Ir al inicio'),
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
              const SizedBox(height: 4),
              Text('Puedes pagar con Stripe, QR o transferencia bancaria.',
                  style: estiloMuted),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _metodoPago,
                onChanged: (v) => setState(() => _metodoPago = v ?? _metodoPago),
                child: Column(
                  children: [
                    for (final m in const [
                      {'nombre': 'STRIPE', 'titulo': 'Stripe (tarjeta)'},
                      {'nombre': 'QR', 'titulo': 'QR Simple (Red Enlace)'},
                      {'nombre': 'MERCADO_PAGO', 'titulo': 'Mercado Pago'},
                      {'nombre': 'PAYPAL', 'titulo': 'PayPal'},
                      {'nombre': 'TRANSFERENCIA', 'titulo': 'Transferencia bancaria'},
                    ])
                      RadioListTile<String>(
                        value: m['nombre']!,
                        title: Text(m['titulo']!),
                        subtitle: _mensajeMetodo(m['nombre']!).isEmpty
                            ? null
                            : Text(_mensajeMetodo(m['nombre']!), style: estiloMuted),
                        dense: true,
                      ),
                  ],
                ),
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
