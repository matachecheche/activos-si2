import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/json_util.dart';
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
      ]);
      if (!mounted) return;
      setState(() {
        _empresas = resultados[0] as List<dynamic>;
        _metricas = resultados[1] as Map<String, dynamic>;
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

  /// HU-12: detalle completo de la empresa (mismo endpoint que la web).
  Future<void> _verDetalle(Map<String, dynamic> empresa) async {
    try {
      final detalle = await _servicio.detalleEmpresa(entero(empresa['id']));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Detalle de ${texto(empresa['nombre'])}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(detalle),
                style: estiloMono.copyWith(fontSize: 11, fontWeight: FontWeight.normal),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Color _colorEstado(String estado) => switch (estado) {
        'ACTIVA' => const Color(0xFF166534),
        'SUSPENDIDA' => const Color(0xFFB45309),
        _ => const Color(0xFF991B1B),
      };

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
              Text('Registrada: ${texto(e['fechaRegistro'])}'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Ver detalle'),
                  onPressed: () => _verDetalle(e),
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
