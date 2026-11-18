import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/json_util.dart';
import '../services/plataforma_service.dart';
import '../services/suscripcion_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// HU-11: plan actual, limites/uso y contratacion o cambio de plan (pago sandbox).
class SuscripcionScreen extends StatefulWidget {
  const SuscripcionScreen({super.key});

  @override
  State<SuscripcionScreen> createState() => _SuscripcionScreenState();
}

class _SuscripcionScreenState extends State<SuscripcionScreen> {
  final SuscripcionService _suscripcion = SuscripcionService();
  final PlataformaService _plataforma = PlataformaService();

  Map<String, dynamic> _info = {};
  List<dynamic> _planes = [];
  bool _cargando = true;
  bool _ocupado = false;
  String? _aviso;
  /// Estado de la pasarela de pagos real.
  Map<String, dynamic> _pasarela = {};
  /// Referencia del pago abierto (para consultar su estado).
  String _referenciaPago = '';
  /// Imagen del codigo QR en base64 (data URL) cuando se paga con QR.
  String _qrImagen = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final resultados = await Future.wait([
        _suscripcion.miSuscripcion(),
        _plataforma.planes(),
        _suscripcion.estadoPasarela(),
      ]);
      if (!mounted) return;
      setState(() {
        _info = resultados[0] as Map<String, dynamic>;
        _planes = (resultados[1] as List).where((p) => mapa(p)['activo'] != false).toList();
        _pasarela = resultados[2] as Map<String, dynamic>;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _aviso = '$e';
      });
    }
  }

  Future<void> _contratar(Map<String, dynamic> plan) async {
    String metodo = 'MERCADO_PAGO';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setEstado) => AlertDialog(
          title: Text('Contratar ${texto(plan['nombre'])}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bs ${numero(plan['precioMensual']).toStringAsFixed(0)} mensuales.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_pasarela['configurado'] == true
                ? 'Método de pago (pasarela real: ${texto(_pasarela['nombreProveedor'])}):'
                : 'Método de pago: la pasarela real no esta configurada.'),
            RadioGroup<String>(
              groupValue: metodo,
              onChanged: (v) => setEstado(() => metodo = v ?? metodo),
              child: const Column(children: [
                RadioListTile<String>(
                  value: 'MERCADO_PAGO',
                  title: Text('Mercado Pago'),
                ),
                RadioListTile<String>(
                  value: 'PAYPAL',
                  title: Text('PayPal'),
                ),
                RadioListTile<String>(
                  value: 'STRIPE',
                  title: Text('Stripe'),
                ),
                RadioListTile<String>(
                  value: 'QR',
                  title: Text('QR Simple (Red Enlace)'),
                ),
                RadioListTile<String>(
                  value: 'TRANSFERENCIA',
                  title: Text('Transferencia'),
                ),
              ]),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirmar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      final res = await _suscripcion.contratar(planId: entero(plan['id']), metodoPago: metodo);
      final url = texto(res['checkoutUrl']);
      _referenciaPago = texto(res['referencia']);
      final qr = texto(res['qrImagen']);
      if (qr.isNotEmpty) {
        // QR Simple: se escanea el codigo con la app del banco.
        if (mounted) setState(() => _qrImagen = qr);
        await _mostrarQr(qr, texto(res['montoPasarela']));
      } else if (url.isNotEmpty) {
        // Pasarela real: se abre el checkout en el navegador del telefono.
        final abierto = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(abierto
                ? 'Se abrio la pasarela de pago. La suscripcion se activa al confirmarse el pago.'
                : 'No se pudo abrir el navegador. Copia el enlace: $url'),
          ));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(texto(res['mensaje']).isNotEmpty ? texto(res['mensaje']) : 'Pago registrado.'),
        ));
      }
      await _cargar();
    } catch (e) {
      if (mounted) {
        setState(() => _aviso = '$e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Muestra el codigo QR de pago y permite comprobar el estado del cobro.
  Future<void> _mostrarQr(String dataUrl, String monto) async {
    final base64 = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paga con el codigo QR'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Escanea el codigo con la app de tu banco. La suscripcion se activa '
              'sola cuando la pasarela confirma el pago.'),
          if (monto.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Monto a pagar: $monto', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(base64Decode(base64), width: 240, height: 240, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Text('Referencia: $_referenciaPago', style: estiloMuted),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _comprobarPago();
            },
            child: const Text('Ya pague'),
          ),
        ],
      ),
    );
  }

  /// Consulta el estado del pago en la pasarela real (servidor a servidor).
  Future<void> _comprobarPago() async {
    if (_referenciaPago.isEmpty) return;
    setState(() => _ocupado = true);
    try {
      final info = await _suscripcion.estadoPago(_referenciaPago);
      if (!mounted) return;
      final estado = texto(info['estado']);
      final mensaje = texto(info['mensaje']);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        estado == 'APROBADO'
            ? 'Pago confirmado: la suscripcion ya esta activa.'
            : (mensaje.isNotEmpty ? mensaje : 'El pago sigue pendiente ($estado).'),
      )));
      if (estado == 'APROBADO') {
        setState(() => _qrImagen = '');
        await _cargar();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo consultar el pago: $e')));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/suscripcion'),
      appBar: barraModulo('Mi suscripción', '/suscripcion'),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_aviso != null)
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B)))),
                  if (_pasarela.isNotEmpty && _pasarela['configurado'] != true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(
                        'Pagos reales no configurados. ${texto(_pasarela['mensaje'])}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                    ),
                  if (_pasarela['configurado'] == true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6EE7B7)),
                      ),
                      child: Text(
                        'Pasarela activa: ${texto(_pasarela['nombreProveedor'])} (moneda ${texto(_pasarela['moneda'])}).',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF065F46)),
                      ),
                    ),
                  _tarjetaActual(),
                  const SizedBox(height: 18),
                  const Text('Planes disponibles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  ..._planes.map(_tarjetaPlan),
                ],
              ),
            ),
    );
  }

  /// Tarjeta de la suscripcion vigente. Muestra los datos ya interpretados
  /// (plan, estado, vigencia, empresa, pagos y pasarela): nunca el objeto
  /// crudo de la base de datos.
  Widget _tarjetaActual() {
    final plan = mapa(_info['plan']);
    final empresa = mapa(_info['empresa']);
    final pasarela = mapa(_info['pasarela']);
    final pagos = _info['pagos'] is List ? List<dynamic>.from(_info['pagos'] as List) : <dynamic>[];
    final nombrePlan = texto(plan['nombre']);
    final nombreEmpresa = texto(empresa['nombre']);
    final nit = texto(empresa['nit']);
    final estado = texto(_info['estado']);
    final inicio = valorLegible(_info['fechaInicio']);
    final vencimiento = valorLegible(_info['fechaVencimiento']);
    final proveedor = texto(pasarela['nombreProveedor']);
    final moneda = texto(pasarela['moneda']);
    final pasarelaTexto = pasarela.isEmpty
        ? 'Sin pasarela configurada'
        : (proveedor.isEmpty
            ? 'Sin pasarela configurada'
            : '$proveedor${moneda.isEmpty ? '' : ' ($moneda)'}');
    String pagosTexto;
    if (pagos.isEmpty) {
      pagosTexto = 'Sin pagos registrados';
    } else {
      final ultimo = mapa(pagos.first);
      final monto = numero(ultimo['monto']);
      pagosTexto = '${pagos.length} pago(s). Último: '
          '${valorLegible(ultimo['fecha'])} · Bs ${monto.toStringAsFixed(2)} · '
          '${texto(ultimo['proveedor']).isEmpty ? texto(ultimo['metodo']) : texto(ultimo['proveedor'])} · '
          '${valorLegible(ultimo['estado'])}';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nombrePlan.isEmpty ? 'Sin plan contratado' : 'Plan actual: $nombrePlan',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        _fila('Estado', _textoEstado(estado)),
        _fila('Empresa', nombreEmpresa.isEmpty ? '-' : (nit.isEmpty ? nombreEmpresa : '$nombreEmpresa (NIT $nit)')),
        _fila('Vigencia', '$inicio → $vencimiento'),
        _fila('Pagos', pagosTexto),
        _fila('Pasarela', pasarelaTexto),
      ]),
    );
  }

  /// Etiqueta de estado de suscripcion legible (ACTIVA -> Activa).
  String _textoEstado(String estado) {
    switch (estado) {
      case 'ACTIVA':
        return 'Activa';
      case 'PENDIENTE':
        return 'Pendiente de pago';
      case 'CANCELADA':
        return 'Cancelada';
      case 'VENCIDA':
        return 'Vencida';
      case 'SUSPENDIDA':
        return 'Suspendida';
      default:
        return estado.isEmpty ? '-' : estado;
    }
  }

  /// Fila etiqueta/valor: el valor va en Expanded para que nunca se corte
  /// ni se apile el texto cuando es largo.
  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 96, child: Text(etiqueta, style: estiloMuted)),
        const SizedBox(width: 10),
        Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _tarjetaPlan(dynamic p) {
    final m = mapa(p);
    final caracteristicas = <String>[
      '${m['maxUsuarios'] ?? 'Usuarios ilimitados'} usuarios',
      '${m['maxActivos'] ?? 'Activos ilimitados'} activos',
      if (m['incluyeBi'] == true) 'Tablero BI',
      if (m['incluyeConsultasDinamicas'] == true) 'Consultas dinámicas',
      if (m['respaldoProgramado'] == true) 'Respaldos programados',
      if (m['idiomaAdicional'] == true) 'Idioma inglés',
      if (m['personalizacionCompleta'] == true) 'Personalización completa',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: decoracionTarjeta(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(texto(m['nombre']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Text('Bs ${numero(m['precioMensual']).toStringAsFixed(0)}/mes',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1769E0))),
          ]),
          const SizedBox(height: 8),
          ...caracteristicas.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF166534)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c, style: const TextStyle(fontSize: 13))),
                ]),
              )),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _ocupado ? null : () => _contratar(m),
              child: const Text('Contratar / cambiar'),
            ),
          ),
        ]),
      ),
    );
  }
}
