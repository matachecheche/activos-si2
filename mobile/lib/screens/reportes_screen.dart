import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/json_util.dart';
import '../services/reporte_service.dart';
import '../widgets/comunes.dart';
import 'constructor_consultas.dart';
import 'navegacion.dart';

/// HU-16: tablero BI (KPIs y distribuciones), consultas guardadas y
/// constructor de consultas, con exportacion a PDF y Excel que se comparte
/// por el sistema operativo. Cubre las mismas funciones que la web.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> with SingleTickerProviderStateMixin {
  final ReporteService _servicio = ReporteService();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  Map<String, dynamic> _bi = {};
  List<dynamic> _guardadas = [];
  bool _cargando = true;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _aviso = null;
    });
    try {
      final resultados = await Future.wait([
        _servicio.bi(),
        _consultasGuardadas(),
      ]);
      if (!mounted) return;
      setState(() {
        _bi = resultados[0] as Map<String, dynamic>;
        _guardadas = resultados[1] as List<dynamic>;
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

  Future<List<dynamic>> _consultasGuardadas() async {
    try {
      return await _servicio.consultasGuardadas();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _recargarGuardadas() async {
    final lista = await _consultasGuardadas();
    if (!mounted) return;
    setState(() => _guardadas = lista);
  }

  Future<void> _ejecutar(Map<String, dynamic> consulta) async {
    final id = entero(consulta['id']);
    try {
      final r = await _servicio.ejecutarGuardada(id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _hojaResultado(texto(consulta['nombre']), r),
      );
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _exportar(Map<String, dynamic> consulta, bool pdf) async {
    try {
      final espec = jsonDecode(texto(consulta['definicion'])) as Map<String, Object?>;
      final bytes = pdf ? await _servicio.exportarPdf(espec) : await _servicio.exportarExcel(espec);
      final nombre = '${texto(consulta['nombre']).replaceAll(' ', '_')}.${pdf ? 'pdf' : 'xlsx'}';
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: nombre,
          mimeType: pdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ], subject: texto(consulta['nombre']));
    } catch (e) {
      if (mounted) _snack('No se pudo exportar: $e');
    }
  }

  Future<void> _eliminar(Map<String, dynamic> consulta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar consulta'),
        content: Text('¿Eliminar "${texto(consulta['nombre'])}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _servicio.eliminarGuardada(entero(consulta['id']));
      await _recargarGuardadas();
      if (mounted) _snack('Consulta eliminada.');
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  void _snack(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/reportes'),
      appBar: barraModulo(
        'Reportes y tablero BI', '/reportes',
        abajo: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Tablero'),
            Tab(text: 'Guardadas'),
            Tab(text: 'Constructor'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              _tablero(),
              _guardadasLista(),
              ConstructorConsultas(alGuardar: _recargarGuardadas),
            ]),
    );
  }

  // ------------------------------------------------------------- tablero

  Widget _tablero() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_aviso != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B)))),
          const Text('Indicadores clave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: _kpis()),
          const SizedBox(height: 20),
          const Text('Activos por estado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ..._barras(_bi['activosPorEstado'], 'estado', 'cantidad'),
          const SizedBox(height: 16),
          const Text('Activos por categoría', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ..._barras(_bi['activosPorCategoria'], 'categoria', 'cantidad'),
          const SizedBox(height: 20),
          const Text('Depreciación mensual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ..._barras(_bi['depreciacionMensual'], 'periodo', 'monto'),
        ],
      ),
    );
  }

  Widget _kpi(String etiqueta, dynamic valor, {bool moneda = false}) {
    final textoValor = moneda ? 'Bs ${numero(valor).toStringAsFixed(0)}' : entero(valor).toString();
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: decoracionTarjeta(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(textoValor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(etiqueta, style: estiloMuted),
      ]),
    );
  }

  List<Widget> _kpis() => [
        _kpi('Total de activos', _bi['totalActivos']),
        _kpi('Valor total', _bi['valorTotalActivos'], moneda: true),
        _kpi('Depreciación acumulada', _bi['depreciacionAcumulada'], moneda: true),
        _kpi('Valor en libros', _bi['valorEnLibros'], moneda: true),
        _kpi('Mantenimientos pendientes', _bi['mantenimientosPendientes']),
        _kpi('Costo de mantenimientos', _bi['costoMantenimientos'], moneda: true),
      ];

  List<Widget> _barras(dynamic datos, String campoEtiqueta, String campoValor) {
    final filas = (datos as List?) ?? const [];
    if (filas.isEmpty) return [const Text('Sin datos.', style: estiloMuted)];
    final maximo = filas
        .map((f) => entero(mapa(f)[campoValor]))
        .fold<int>(1, (a, b) => b > a ? b : a);
    return filas.map((f) {
      final m = mapa(f);
      final valor = entero(m[campoValor]);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(texto(m[campoEtiqueta]), style: const TextStyle(fontSize: 13))),
            Text('$valor', style: estiloMuted),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: maximo == 0 ? 0 : valor / maximo,
              minHeight: 8,
              backgroundColor: const Color(0xFFEEF2F7),
            ),
          ),
        ]),
      );
    }).toList();
  }

  // ------------------------------------------------------------ guardadas

  Widget _guardadasLista() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Text('Consultas guardadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Text('${_guardadas.length}', style: estiloMuted),
          ]),
          const SizedBox(height: 8),
          if (_guardadas.isEmpty)
            const Text(
              'Aún no hay consultas guardadas. Créalas en la pestaña Constructor o en la web.',
              style: estiloMuted,
            ),
          ..._guardadas.map((c) {
            final m = mapa(c);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: decoracionTarjeta(),
              child: ListTile(
                title: Text(texto(m['nombre'])),
                subtitle: Text(texto(m['entidad'], 'sin tabla'), style: estiloMuted),
                onTap: () => _ejecutar(m),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'pdf') _exportar(m, true);
                    if (v == 'excel') _exportar(m, false);
                    if (v == 'borrar') _eliminar(m);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
                    PopupMenuItem(value: 'excel', child: Text('Exportar Excel')),
                    PopupMenuItem(value: 'borrar', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _hojaResultado(String titulo, Map<String, dynamic> r) {
    final columnas = (r['columnas'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final filas = (r['filas'] as List?) ?? const [];
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Text('${filas.length} filas', style: estiloMuted),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                      columns: columnas.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
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
      ]),
    );
  }
}
