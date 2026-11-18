import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/json_util.dart';
import '../services/respaldo_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// HU-15: respaldos SHA-256, programacion DIARIA/SEMANAL y restauracion
/// transaccional (el backend crea un respaldo de seguridad antes de restaurar).
class RespaldosScreen extends StatefulWidget {
  const RespaldosScreen({super.key});

  @override
  State<RespaldosScreen> createState() => _RespaldosScreenState();
}

class _RespaldosScreenState extends State<RespaldosScreen> {
  final RespaldoService _servicio = RespaldoService();
  List<dynamic> _respaldos = [];
  Map<String, dynamic> _programacion = {};
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
        _servicio.listar(),
        _servicio.verProgramacion(),
      ]);
      if (!mounted) return;
      setState(() {
        _respaldos = resultados[0] as List<dynamic>;
        _programacion = resultados[1] as Map<String, dynamic>;
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

  Future<void> _crear() async {
    setState(() => _ocupado = true);
    try {
      await _servicio.crear();
      if (mounted) _snack('Respaldo creado correctamente.');
      await _cargar();
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _restaurar(Map<String, dynamic> respaldo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.restore, color: Color(0xFFB45309)),
        title: const Text('¿Restaurar este respaldo?'),
        content: Text(
          'Se restaurará la base desde ${texto(respaldo['nombreArchivo'], texto(respaldo['archivo']))}.\n\n'
          'El sistema crea primero un respaldo de seguridad de forma automática.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _ocupado = true);
    try {
      await _servicio.restaurar(entero(respaldo['id']));
      if (mounted) _snack('Restauración completada.');
      await _cargar();
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editarProgramacion() async {
    final frecuencia = TextEditingController(text: texto(_programacion['frecuencia'], 'DIARIA'));
    final hora = TextEditingController(text: texto(_programacion['hora'], '02:00'));
    final copias = TextEditingController(text: entero(_programacion['copiasAConservar'], 3).toString());
    bool activa = _programacion['activa'] != false;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setEstado) => AlertDialog(
          title: const Text('Programación de respaldos'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: frecuencia.text,
              decoration: decoracion('Frecuencia'),
              items: const [
                DropdownMenuItem(value: 'DIARIA', child: Text('Diaria')),
                DropdownMenuItem(value: 'SEMANAL', child: Text('Semanal')),
              ],
              onChanged: (v) => frecuencia.text = v ?? 'DIARIA',
            ),
            const SizedBox(height: 10),
            TextField(controller: hora, decoration: decoracion('Hora', sugerencia: 'HH:mm')),
            const SizedBox(height: 10),
            TextField(
              controller: copias,
              keyboardType: TextInputType.number,
              decoration: decoracion('Copias a conservar'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Programación activa'),
              value: activa,
              onChanged: (v) => setEstado(() => activa = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (guardar != true) return;
    try {
      await _servicio.guardarProgramacion({
        'frecuencia': frecuencia.text,
        'hora': hora.text,
        'copiasAConservar': int.tryParse(copias.text) ?? 3,
        'activa': activa,
        'destino': texto(_programacion['destino'], 'LOCAL'),
      });
      await _cargar();
      if (mounted) _snack('Programación guardada.');
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  /// HU-15: descarga el archivo del respaldo y lo comparte/guarda con el
  /// menu del sistema (equivalente al boton "Descargar" de la web).
  Future<void> _descargar(Map<String, dynamic> respaldo) async {
    try {
      final bytes = await _servicio.descargar(entero(respaldo['id']));
      final nombre = texto(respaldo['nombreArchivo'], texto(respaldo['archivo'], 'respaldo_${respaldo['id']}.afb'));
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: nombre,
          mimeType: 'application/octet-stream',
        ),
      ], subject: nombre);
    } catch (e) {
      if (mounted) _snack('No se pudo descargar: $e');
    }
  }

  void _snack(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/respaldos'),
      appBar: barraModulo('Respaldos', '/respaldos', acciones: [
        IconButton(tooltip: 'Programación', icon: const Icon(Icons.schedule_outlined), onPressed: _editarProgramacion),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ocupado ? null : _crear,
        icon: const Icon(Icons.backup_outlined),
        label: Text(_ocupado ? '...' : 'Crear respaldo'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (_programacion.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: decoracionTarjeta(),
                      child: Text(
                        'Programación: ${texto(_programacion['frecuencia'])} a las ${texto(_programacion['hora'])} · '
                        '${_programacion['activa'] == false ? 'inactiva' : 'activa'} · '
                        '${entero(_programacion['copiasAConservar'], 3)} copias',
                        style: estiloMuted,
                      ),
                    ),
                  if (_aviso != null)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B)))),
                  ..._respaldos.map((r) => _fila(mapa(r))),
                  if (_respaldos.isEmpty) const Text('Todavía no se generaron respaldos.', style: estiloMuted),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _fila(Map<String, dynamic> r) {
    final hash = texto(r['sha256']);
    final hashCorto = hash.length > 16 ? '${hash.substring(0, 16)}…' : hash;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: decoracionTarjeta(),
      child: ListTile(
        leading: const Icon(Icons.archive_outlined),
        title: Text(texto(r['nombreArchivo'], texto(r['archivo']))),
        subtitle: Text(
          '${texto(r['fecha'])} · ${texto(r['tipo'])} · ${_kb(r['tamanoBytes'])}\n'
          'SHA-256: $hashCorto',
          style: estiloMono.copyWith(fontSize: 10.5),
        ),
        isThreeLine: true,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Descargar',
            icon: const Icon(Icons.download_outlined),
            onPressed: _ocupado ? null : () => _descargar(r),
          ),
          IconButton(
            tooltip: 'Restaurar',
            icon: const Icon(Icons.restore_page_outlined, color: Color(0xFFB45309)),
            onPressed: _ocupado ? null : () => _restaurar(r),
          ),
        ]),
      ),
    );
  }

  String _kb(dynamic bytes) {
    final b = entero(bytes);
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
