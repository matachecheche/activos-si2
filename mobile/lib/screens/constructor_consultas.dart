import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/json_util.dart';
import '../services/reporte_service.dart';
import '../widgets/comunes.dart';

/// HU-14/HU-16: constructor de consultas en el movil, con la misma cobertura
/// que la web: tabla, columnas, filtros (=, !=, >, >=, <, <=, LIKE, IN,
/// BETWEEN, IS NULL...), orden, limite, agregacion (COUNT/SUM/AVG/MIN/MAX),
/// ejecucion, guardado y exportacion a PDF/Excel.
class ConstructorConsultas extends StatefulWidget {
  /// Se invoca cuando se guarda una consulta (para refrescar la pestaña).
  final VoidCallback? alGuardar;

  const ConstructorConsultas({super.key, this.alGuardar});

  @override
  State<ConstructorConsultas> createState() => _ConstructorConsultasState();
}

class _FiltroUi {
  String campo;
  String operador;
  final TextEditingController valor;
  final TextEditingController valorHasta;
  final TextEditingController valores;

  _FiltroUi(this.campo, {this.operador = '='})
      : valor = TextEditingController(),
        valorHasta = TextEditingController(),
        valores = TextEditingController();

  void dispose() {
    valor.dispose();
    valorHasta.dispose();
    valores.dispose();
  }
}

class _ConstructorConsultasState extends State<ConstructorConsultas> {
  static const List<String> _operadores = [
    '=', '!=', '>', '>=', '<', '<=', 'LIKE', 'NOT LIKE', 'IN', 'BETWEEN', 'IS NULL', 'IS NOT NULL'
  ];
  static const List<String> _funciones = ['COUNT', 'SUM', 'AVG', 'MIN', 'MAX'];

  final ReporteService _servicio = ReporteService();
  final TextEditingController _limite = TextEditingController(text: '100');

  List<Map<String, dynamic>> _tablas = [];
  String _entidad = '';
  final List<String> _columnas = [];
  final List<_FiltroUi> _filtros = [];
  String _ordenCampo = '';
  String _ordenDir = 'ASC';
  String _funcion = '';
  String _campoAg = '*';
  final List<String> _agrupar = [];

  bool _cargando = true;
  bool _ejecutando = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _limite.dispose();
    for (final f in _filtros) {
      f.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? get _tabla {
    for (final t in _tablas) {
      if (t['tabla'] == _entidad) return t;
    }
    return _tablas.isEmpty ? null : _tablas.first;
  }

  List<Map<String, dynamic>> get _columnasTabla {
    final columnas = (_tabla?['columnas'] as List?) ?? const [];
    return columnas.map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  Future<void> _cargarCatalogo() async {
    try {
      final datos = await _servicio.catalogo();
      if (!mounted) return;
      final tablas = datos.map((t) => Map<String, dynamic>.from(t as Map)).toList();
      setState(() {
        _tablas = tablas;
        _entidad = tablas.isEmpty ? '' : texto(tablas.first['tabla']);
        _cargando = false;
        _seleccionPorDefecto();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _aviso = '$e';
      });
    }
  }

  /// Igual que la web: al elegir una tabla se marcan sus primeras 5 columnas.
  void _seleccionPorDefecto() {
    _columnas
      ..clear()
      ..addAll(_columnasTabla.take(5).map((c) => texto(c['nombre'])));
    final viejos = List<_FiltroUi>.from(_filtros);
    _filtros.clear();
    // Se liberan despues del cuadro para no tocar controladores aun montados.
    if (viejos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final f in viejos) {
          f.dispose();
        }
      });
    }
    _ordenCampo = '';
    _funcion = '';
    _campoAg = '*';
    _agrupar.clear();
  }

  void _cambiarEntidad(String? nueva) {
    if (nueva == null || nueva == _entidad) return;
    setState(() {
      _entidad = nueva;
      _aviso = null;
      _seleccionPorDefecto();
    });
  }

  void _agregarFiltro() {
    final columnas = _columnasTabla;
    setState(() {
      _filtros.add(_FiltroUi(columnas.isEmpty ? '' : texto(columnas.first['nombre'])));
    });
  }

  void _quitarFiltro(int indice) {
    late _FiltroUi quitado;
    setState(() {
      quitado = _filtros.removeAt(indice);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => quitado.dispose());
  }

  /// Construye el JSON que valida el motor de consultas (whitelist del backend).
  Map<String, Object?> _espec() {
    final filtros = <Map<String, Object?>>[];
    for (final f in _filtros) {
      if (f.campo.isEmpty || f.operador.isEmpty) continue;
      final mapa = <String, Object?>{'campo': f.campo, 'operador': f.operador};
      switch (f.operador) {
        case 'BETWEEN':
          mapa['valor'] = f.valor.text.trim();
          mapa['valorHasta'] = f.valorHasta.text.trim();
          break;
        case 'IN':
          mapa['valores'] = f.valores.text
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList();
          break;
        case 'IS NULL':
        case 'IS NOT NULL':
          break;
        default:
          mapa['valor'] = f.valor.text.trim();
      }
      filtros.add(mapa);
    }

    return <String, Object?>{
      'entidad': _entidad,
      'columnas': List<String>.from(_columnas),
      'filtros': filtros,
      'orden': _ordenCampo.isEmpty
          ? <Map<String, Object?>>[]
          : <Map<String, Object?>>[
              {'campo': _ordenCampo, 'direccion': _ordenDir}
            ],
      'limite': int.tryParse(_limite.text.trim()) ?? 100,
      'agregacion': _funcion.isEmpty
          ? null
          : <String, Object?>{
              'funcion': _funcion,
              'campo': _campoAg,
              'agruparPor': List<String>.from(_agrupar),
            },
    };
  }

  Future<void> _ejecutar() async {
    if (_columnas.isEmpty && _funcion.isEmpty) {
      setState(() => _aviso = 'Elige al menos una columna o una agregación.');
      return;
    }
    setState(() {
      _ejecutando = true;
      _aviso = null;
    });
    try {
      final resultado = await _servicio.consultar(_espec());
      if (!mounted) return;
      setState(() => _ejecutando = false);
      await _mostrarResultado('Consulta ${_tabla?['etiqueta'] ?? _entidad}', resultado, _espec());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ejecutando = false;
        _aviso = '$e';
      });
    }
  }

  Future<void> _guardar() async {
    final nombreCtrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Guardar consulta'),
        content: TextField(
          controller: nombreCtrl,
          autofocus: true,
          decoration: decoracion('Nombre de la consulta'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nombreCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    nombreCtrl.dispose();
    if (nombre == null || nombre.isEmpty) return;
    try {
      await _servicio.guardarConsulta(
        nombre: nombre,
        entidad: _entidad,
        definicion: jsonEncode(_espec()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Consulta "$nombre" guardada.')));
      widget.alGuardar?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _exportar(Map<String, Object?> espec, bool pdf) async {
    try {
      final bytes = pdf ? await _servicio.exportarPdf(espec) : await _servicio.exportarExcel(espec);
      final nombre = 'consulta_$_entidad.${pdf ? 'pdf' : 'xlsx'}';
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: nombre,
          mimeType: pdf
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ], subject: 'Consulta $_entidad');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
      }
    }
  }

  Future<void> _mostrarResultado(
      String titulo, Map<String, dynamic> resultado, Map<String, Object?> espec) async {
    final columnas = (resultado['columnas'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final filas = (resultado['filas'] as List?) ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (sheetContext, controller) => Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Text('${filas.length} filas', style: estiloMuted),
              IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(sheetContext)),
            ]),
          ),
          Expanded(
            child: filas.isEmpty
                ? const Center(child: Text('La consulta no devolvió filas.'))
                : SingleChildScrollView(
                    controller: controller,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: columnas
                            .map((c) => DataColumn(
                                label: Text(c,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                            .toList(),
                        rows: filas.map((f) {
                          final m = mapa(f);
                          return DataRow(
                            cells: columnas
                                .map((c) => DataCell(Text(valorLegible(m[c]), style: const TextStyle(fontSize: 12))))
                                .toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                    onPressed: () => _exportar(espec, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Excel'),
                    onPressed: () => _exportar(espec, false),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_tablas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_aviso ?? 'No se pudo cargar el catálogo de consultas.', style: estiloMuted),
        ),
      );
    }

    final columnas = _columnasTabla;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (_aviso != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B))),
          ),
        const Text('1. Tabla', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: decoracion('Datos permitidos'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _entidad,
              isDense: true,
              isExpanded: true,
              items: _tablas
                  .map((t) => DropdownMenuItem(
                        value: texto(t['tabla']),
                        child: Text(texto(t['etiqueta'])),
                      ))
                  .toList(),
              onChanged: _cambiarEntidad,
            ),
          ),
        ),
        if ((_tabla?['descripcion'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(texto(_tabla!['descripcion']), style: estiloMuted),
          ),
        const SizedBox(height: 18),
        Row(children: [
          const Text('2. Columnas', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_columnas.length} elegidas', style: estiloMuted),
        ]),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: columnas.map((c) {
            final nombre = texto(c['nombre']);
            final seleccionada = _columnas.contains(nombre);
            return FilterChip(
              label: Text(texto(c['etiqueta'], nombre)),
              selected: seleccionada,
              onSelected: (_) => setState(() {
                if (seleccionada) {
                  _columnas.remove(nombre);
                } else {
                  _columnas.add(nombre);
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Row(children: [
          const Text('3. Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: _agregarFiltro,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
          ),
        ]),
        if (_filtros.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Sin filtros: se devuelven las primeras filas.', style: estiloMuted),
          ),
        ..._filtros.asMap().entries.map((entrada) => _tarjetaFiltro(entrada.key, entrada.value, columnas)),
        const SizedBox(height: 12),
        const Text('4. Orden y límite', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: InputDecorator(
              decoration: decoracion('Ordenar por'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _ordenCampo,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sin ordenar')),
                    ...columnas.map((c) => DropdownMenuItem(
                          value: texto(c['nombre']),
                          child: Text(texto(c['etiqueta'], texto(c['nombre']))),
                        )),
                  ],
                  onChanged: (v) => setState(() => _ordenCampo = v ?? ''),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: InputDecorator(
              decoration: decoracion('Sentido'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _ordenDir,
                  isDense: true,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'ASC', child: Text('ASC')),
                    DropdownMenuItem(value: 'DESC', child: Text('DESC')),
                  ],
                  onChanged: (v) => setState(() => _ordenDir = v ?? 'ASC'),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _limite,
            keyboardType: TextInputType.number,
            decoration: decoracion('Límite de filas', ayuda: 'Entre 1 y 500'),
          ),
        ),
        const SizedBox(height: 18),
        const Text('5. Agregación (opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: InputDecorator(
              decoration: decoracion('Función'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _funcion,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sin agregación')),
                    ..._funciones.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                  ],
                  onChanged: (v) => setState(() => _funcion = v ?? ''),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InputDecorator(
              decoration: decoracion('Campo'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _campoAg,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: '*', child: Text('* (todo)')),
                    ...columnas.map((c) => DropdownMenuItem(
                          value: texto(c['nombre']),
                          child: Text(texto(c['nombre'])),
                        )),
                  ],
                  onChanged: _funcion.isEmpty ? null : (v) => setState(() => _campoAg = v ?? '*'),
                ),
              ),
            ),
          ),
        ]),
        if (_funcion.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Agrupar por (${_agrupar.length} elegidas)', style: estiloMuted),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: columnas.map((c) {
              final nombre = texto(c['nombre']);
              return FilterChip(
                label: Text(texto(c['etiqueta'], nombre)),
                selected: _agrupar.contains(nombre),
                onSelected: (_) => setState(() {
                  if (_agrupar.contains(nombre)) {
                    _agrupar.remove(nombre);
                  } else {
                    _agrupar.add(nombre);
                  }
                }),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _ejecutando ? null : _ejecutar,
          icon: _ejecutando
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow),
          label: Text(_ejecutando ? 'Ejecutando...' : 'Ejecutar consulta'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar consulta'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _tarjetaFiltro(int indice, _FiltroUi filtro, List<Map<String, dynamic>> columnas) {
    final sinValor = filtro.operador == 'IS NULL' || filtro.operador == 'IS NOT NULL';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: decoracionTarjeta(),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: InputDecorator(
              decoration: decoracion('Campo'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: columnas.any((c) => texto(c['nombre']) == filtro.campo) ? filtro.campo : columnas.firstOrNullNombre(),
                  isDense: true,
                  isExpanded: true,
                  items: columnas
                      .map((c) => DropdownMenuItem(
                            value: texto(c['nombre']),
                            child: Text(texto(c['etiqueta'], texto(c['nombre']))),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => filtro.campo = v ?? ''),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Quitar filtro',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _quitarFiltro(indice),
          ),
        ]),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: decoracion('Operador'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: filtro.operador,
              isDense: true,
              isExpanded: true,
              items: _operadores.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) => setState(() => filtro.operador = v ?? '='),
            ),
          ),
        ),
        if (filtro.operador == 'BETWEEN') ...[
          const SizedBox(height: 8),
          TextField(controller: filtro.valor, decoration: decoracion('Desde')),
          const SizedBox(height: 8),
          TextField(controller: filtro.valorHasta, decoration: decoracion('Hasta')),
        ] else if (filtro.operador == 'IN') ...[
          const SizedBox(height: 8),
          TextField(
            controller: filtro.valores,
            decoration: decoracion('Valores separados por coma', ayuda: 'Ej: DISPONIBLE, EN_MANTENIMIENTO'),
          ),
        ] else if (!sinValor) ...[
          const SizedBox(height: 8),
          TextField(controller: filtro.valor, decoration: decoracion('Valor')),
        ],
      ]),
    );
  }
}

extension _PrimerNombre on List<Map<String, dynamic>> {
  String? firstOrNullNombre() =>
      isEmpty ? null : texto((first['nombre'] ?? '').toString());
}
