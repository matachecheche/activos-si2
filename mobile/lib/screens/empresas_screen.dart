import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/json_util.dart';
import '../services/auth_service.dart';
import '../services/plataforma_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// HU-11: gestion de empresas de la plataforma (exclusivo Super Admin).
/// Permite ver metricas y activar/suspender empresas.
class EmpresasScreen extends StatefulWidget {
  const EmpresasScreen({super.key});

  @override
  State<EmpresasScreen> createState() => _EmpresasScreenState();
}

class _EmpresasScreenState extends State<EmpresasScreen> {
  final PlataformaService _servicio = PlataformaService();
  List<dynamic> _empresas = [];
  Map<String, dynamic> _metricas = {};
  /// Ronda 11: transferencias bancarias pendientes de confirmar.
  List<Map<String, dynamic>> _transferencias = [];
  bool _cargando = true;
  bool _ocupado = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final resultados = await Future.wait([
        _servicio.empresas(),
        _servicio.metricas(),
        _servicio.transferencias().catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _empresas = resultados[0] as List<dynamic>;
        _metricas = resultados[1] as Map<String, dynamic>;
        _transferencias = (resultados[2] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
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

  /// Ronda 11: confirma el deposito de una transferencia bancaria.
  Future<void> _aprobarTransferencia(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar deposito'),
        content: Text(
          'Confirma el deposito de Bs ${t['monto']} de "${texto(t['empresa'], 'la empresa')}"?\n\n'
          'La suscripcion quedara activa al instante.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      final r = await _servicio.aprobarTransferencia(texto(t['referencia']));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto(r['mensaje'], 'Transferencia confirmada.'))),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _aviso = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Ronda 11: rechaza una transferencia bancaria.
  Future<void> _rechazarTransferencia(Map<String, dynamic> t) async {
    setState(() => _ocupado = true);
    try {
      final r = await _servicio.rechazarTransferencia(texto(t['referencia']), 'No se recibio el deposito');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto(r['mensaje'], 'Transferencia rechazada.'))),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _aviso = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Tarjeta con las transferencias pendientes de confirmar.
  Widget _tarjetaTransferencias() {
    if (_transferencias.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: decoracionTarjeta(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transferencias bancarias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Confirma el deposito para activar la suscripcion de la empresa.', style: estiloMuted),
          const SizedBox(height: 10),
          ..._transferencias.map((t) {
            final pendiente = texto(t['estado']) == 'PENDIENTE';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${texto(t['empresa'], 'Empresa')} · Bs ${t['monto']}'),
                  Text('Referencia: ${texto(t['referencia'])}', style: estiloMuted),
                  Text('Estado: ${texto(t['estado'])}', style: estiloMuted),
                  if (pendiente) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      FilledButton(
                        onPressed: _ocupado ? null : () => _aprobarTransferencia(t),
                        child: const Text('Confirmar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _ocupado ? null : () => _rechazarTransferencia(t),
                        child: const Text('Rechazar'),
                      ),
                    ]),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _cambiarEstado(Map<String, dynamic> empresa, String nuevoEstado) async {
    setState(() => _ocupado = true);
    try {
      await _servicio.cambiarEstado(entero(empresa['id']), nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Empresa $nuevoEstado')));
      }
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Ronda 10: completa los datos de ejemplo de la empresa (categorias, areas,
  /// activos, presupuestos, mantenimiento, inventario...). Solo crea lo que
  /// falta: nunca pisa datos reales.
  Future<void> _completarEjemplo(Map<String, dynamic> empresa) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Datos de ejemplo'),
        content: Text('Se crearan categorias, areas, ubicaciones, activos, presupuestos, '
            'mantenimientos e inventario de ejemplo para "${texto(empresa['nombre'])}", '
            'SOLO si esa empresa no los tiene. No se pisa ningun dato real.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Completar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      final r = await _servicio.completarDatosEjemplo(entero(empresa['id']));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        texto(r['estado']) == 'OK'
            ? 'Datos de ejemplo listos para ${texto(empresa['nombre'])}.'
            : 'No se pudieron completar los datos de ejemplo.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// HU-12: detalle completo de la empresa (mismo endpoint que la web).
  Future<void> _verDetalle(Map<String, dynamic> empresa) async {
    try {
      final detalle = await _servicio.detalleEmpresa(entero(empresa['id']));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Detalle de ${texto(empresa['nombre'])}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('Usuarios', detalle['usuarios']),
                      _chip('Activos', detalle['activos']),
                      _chip('Presupuestos', detalle['presupuestos']),
                      _chip('Mantenimientos', detalle['mantenimientos']),
                      _chip('Respaldos', detalle['respaldos']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('Detalle técnico (JSON)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    children: [
                      SelectableText(
                        const JsonEncoder.withIndent('  ').convert(detalle),
                        style: estiloMono.copyWith(fontSize: 11, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// Tarjeta compacta con un dato del detalle (conteos reales de uso).
  Widget _chip(String nombre, Object? valor) {
    final numero = valor is num ? valor.toInt() : int.tryParse('${valor ?? ''}') ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$numero',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1769E0))),
          Text(nombre,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) => switch (estado) {
        'ACTIVA' => const Color(0xFF166534),
        'SUSPENDIDA' => const Color(0xFFB45309),
        _ => const Color(0xFF991B1B),
      };

  /// HU-12: el Super Admin entra a la empresa: la sesion pasa a trabajar con
  /// los datos de esa empresa y se vuelve a la pantalla de inicio, donde ya
  /// se ven todos los modulos.
  Future<void> _entrarComo(Map<String, dynamic> empresa) async {
    final nombre = texto(empresa['nombre']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Entrar a $nombre'),
        content: const Text(
            'La sesion del Super Admin pasara a trabajar con los datos de esta empresa. '
            'Podras ver activos, presupuestos, usuarios y respaldos como si fueras su administrador.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Entrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    final error = await AuthService().entrarComoEmpresa(entero(empresa['id']));
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ahora estas trabajando en $nombre')));
    irAModulo(context, '/inicio');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/plataforma/empresas'),
      appBar: barraModulo('Empresas de la plataforma', '/plataforma/empresas'),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_aviso != null)
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B)))),
                  if (_metricas.isNotEmpty)
                    Wrap(spacing: 10, runSpacing: 10, children: _metricas.entries.map((e) {
                      return Container(
                        width: 150,
                        padding: const EdgeInsets.all(12),
                        decoration: decoracionTarjeta(),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${e.value}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(e.key, style: estiloMuted),
                        ]),
                      );
                    }).toList()),
                  _tarjetaTransferencias(),
                  const SizedBox(height: 18),
                  ..._empresas.map((e) => _fila(mapa(e))),
                  if (_empresas.isEmpty) const Text('No hay empresas registradas.', style: estiloMuted),
                ],
              ),
            ),
    );
  }

  Widget _fila(Map<String, dynamic> e) {
    final estado = texto(e['estado'], 'ACTIVA');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: decoracionTarjeta(),
      child: ExpansionTile(
        title: Text(texto(e['nombre']), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('NIT: ${texto(e['nit'])} · ${texto(e['correoContacto'])}', style: estiloMuted),
        trailing: Chip(
          label: Text(estado, style: TextStyle(fontSize: 11, color: _colorEstado(estado))),
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.white,
          side: BorderSide(color: _colorEstado(estado).withValues(alpha: 0.4)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Rubro: ${texto(e['rubro'])}'),
              Text('Registrada: ${valorLegible(e['fechaRegistro'])}'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Ver detalle'),
                  onPressed: () => _verDetalle(e),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Completar datos de ejemplo'),
                  onPressed: _ocupado ? null : () => _completarEjemplo(e),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Entrar como esta empresa'),
                  onPressed: _ocupado ? null : () => _entrarComo(e),
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (estado != 'ACTIVA')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Activar'),
                    onPressed: _ocupado ? null : () => _cambiarEstado(e, 'ACTIVA'),
                  ),
                const SizedBox(width: 8),
                if (estado == 'ACTIVA')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.pause_circle_outline, size: 18),
                    label: const Text('Suspender'),
                    onPressed: _ocupado ? null : () => _cambiarEstado(e, 'SUSPENDIDA'),
                  ),
                const SizedBox(width: 8),
                if (estado != 'CANCELADA')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF991B1B)),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancelar'),
                    onPressed: _ocupado ? null : () => _cambiarEstado(e, 'CANCELADA'),
                  ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
