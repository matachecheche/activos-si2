import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../models/ficha.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/categoria_service.dart';
import '../services/depreciacion_service.dart';
import '../widgets/comunes.dart';
import '../widgets/tabla_depreciacion.dart';
import 'activo_detalle_screen.dart';
import 'estado_util.dart';
import 'navegacion.dart';

String _textoMetodo(String? metodo) {
  if (metodo == null || metodo.isEmpty) return '-';
  if (metodo == 'LINEA_RECTA') return 'Línea recta';
  return metodo;
}

/// HU-07: depreciacion y valor en libros, calculo de periodos pendientes y parametros por categoria.
class DepreciacionScreen extends StatefulWidget {
  const DepreciacionScreen({super.key});

  @override
  State<DepreciacionScreen> createState() => _DepreciacionScreenState();
}

class _DepreciacionScreenState extends State<DepreciacionScreen> {
  final DepreciacionService _service = DepreciacionService();
  final CategoriaService _categoriaService = CategoriaService();
  final AuthService _auth = AuthService();
  final TextEditingController _filtroCtrl = TextEditingController();

  List<ResumenDepreciacion> _resumen = <ResumenDepreciacion>[];
  List<Categoria> _categorias = <Categoria>[];
  String? _error;
  String? _ok;
  bool _cargando = true;
  bool _calculando = false;

  bool get _puedeCalcular => _auth.hasPermission('DEPRECIACION_CREAR');
  bool get _puedeParametrizar => _auth.hasPermission('DEPRECIACION_EDITAR') || _auth.hasPermission('ACTIVOS_EDITAR');

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarCategorias();
  }

  @override
  void dispose() {
    _filtroCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await _service.resumen();
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudo cargar la depreciación.');
      });
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final c = await _categoriaService.listar();
      if (!mounted) return;
      setState(() => _categorias = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _categorias = <Categoria>[]);
    }
  }

  Future<void> _recargarTodo() async {
    await _cargar();
    await _cargarCategorias();
  }

  List<ResumenDepreciacion> get _filtrados {
    final t = _filtroCtrl.text.trim().toLowerCase();
    return _resumen
        .where((r) => t.isEmpty || r.codigo.toLowerCase().contains(t) || r.nombre.toLowerCase().contains(t) || r.categoria.toLowerCase().contains(t))
        .toList();
  }

  Future<void> _calcular() async {
    setState(() {
      _error = null;
      _ok = null;
      _calculando = true;
    });
    try {
      final r = await _service.calcular();
      if (!mounted) return;
      setState(() {
        _calculando = false;
        _ok = r.periodosGenerados > 0
            ? 'Se generaron ${r.periodosGenerados} periodo(s) para ${r.activosProcesados} activo(s) hasta ${r.hasta}.'
            : 'La depreciación de ${r.activosProcesados} activo(s) ya estaba al día hasta ${r.hasta}.';
      });
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculando = false;
        _error = mensajeError(e, 'No se pudo calcular la depreciación.');
      });
    }
  }

  Future<void> _ver(ResumenDepreciacion r) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DepreciacionActivoScreen(activoId: r.activoId)));
  }

  Future<void> _editarCategoria(Categoria c) async {
    final guardado = await abrirHoja<bool>(context, _FormCategoria(categoria: c));
    if (guardado == true && mounted) {
      setState(() {
        _error = null;
        _ok = 'Parámetros actualizados. La depreciación de la categoría se recalculó.';
      });
      _recargarTodo();
    }
  }

  Widget _tarjetaActivo(ResumenDepreciacion r) {
    return Tarjeta(
      onTap: () => _ver(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.codigo, style: estiloMono)),
              insigniaDe(r.estado),
            ],
          ),
          const SizedBox(height: 3),
          Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(r.categoria, style: estiloMuted),
          const SizedBox(height: 6),
          Text(
            'Valor: ${formatoBs(r.valorAdquisicion)} · ${r.depreciable ? 'Vida útil: ${r.vidaUtilAnios ?? '-'} años' : 'No deprecia'}',
            style: estiloMuted,
          ),
          if (r.depreciable) Text('Cuota mensual: ${formatoBs(r.depreciacionMensual)}', style: estiloMuted),
          Text('Acumulada: ${formatoBs(r.depreciacionAcumulada)}', style: estiloMuted),
          Text('En libros: ${formatoBs(r.valorEnLibros)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _filaCategoria(Categoria c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: colorBorde))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Depreciable: ${c.depreciable ? 'Sí' : 'No'}'
                  '${c.depreciable ? ' · Vida útil: ${c.vidaUtil ?? '-'} años' : ''}',
                  style: estiloMuted,
                ),
                Text('Valor residual: ${formatoPorcentaje(c.valorResidualPct)} % · Método: ${_textoMetodo(c.metodoDepreciacion)}', style: estiloMuted),
              ],
            ),
          ),
          if (_puedeParametrizar) TextButton(onPressed: () => _editarCategoria(c), child: const Text('Editar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dep = _resumen.where((r) => r.depreciable).toList();
    double suma(double Function(ResumenDepreciacion r) f) => dep.fold<double>(0, (acc, r) => acc + f(r));
    final filtrados = _filtrados;
    return Scaffold(
      appBar: barraModulo('Depreciación', '/depreciacion', acciones: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _recargarTodo),
      ]),
      drawer: const MenuLateral(rutaActual: '/depreciacion'),
      body: RefreshIndicator(
        onRefresh: _recargarTodo,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Subtitulo('Método de línea recta: (valor de adquisición − valor residual) ÷ vida útil en meses.'),
            if (_puedeCalcular)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(
                  onPressed: _calculando ? null : _calcular,
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(_calculando ? 'Calculando...' : 'Calcular periodos pendientes'),
                ),
              ),
            if (_error != null) BannerMensaje(_error!),
            if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
            GrillaKpi(
              items: [
                TarjetaKpi(etiquetaKpi: 'Activos depreciables', valor: '${dep.length}'),
                TarjetaKpi(etiquetaKpi: 'Valor de adquisición', valor: formatoBs(suma((r) => r.valorAdquisicion))),
                TarjetaKpi(etiquetaKpi: 'Depreciación acumulada', valor: formatoBs(suma((r) => r.depreciacionAcumulada)), tono: TonoKpi.alerta),
                TarjetaKpi(etiquetaKpi: 'Valor en libros', valor: formatoBs(suma((r) => r.valorEnLibros)), tono: TonoKpi.bien),
              ],
            ),
            TarjetaSeccion(
              titulo: 'Activos',
              hijos: [
                TextField(
                  controller: _filtroCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Filtrar por código, nombre o categoría',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filtroCtrl.text.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _filtroCtrl.clear())),
                  ),
                ),
              ],
            ),
            if (_cargando)
              const Cargando()
            else if (filtrados.isEmpty)
              const MensajeVacio('No hay activos para mostrar.')
            else
              for (final r in filtrados) _tarjetaActivo(r),
            const SizedBox(height: 4),
            TarjetaSeccion(
              titulo: 'Parámetros por categoría',
              hijos: [
                const Text(
                  'Vida útil (años), valor residual (%) y método. Al cambiarlos se recalcula la depreciación de la categoría.',
                  style: estiloMuted,
                ),
                const SizedBox(height: 6),
                for (final c in _categorias) _filaCategoria(c),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================================
// Detalle de un activo: tabla de depreciacion por periodo
// ======================================================================================

class DepreciacionActivoScreen extends StatefulWidget {
  final int activoId;

  const DepreciacionActivoScreen({super.key, required this.activoId});

  @override
  State<DepreciacionActivoScreen> createState() => _DepreciacionActivoScreenState();
}

class _DepreciacionActivoScreenState extends State<DepreciacionActivoScreen> {
  final DepreciacionService _service = DepreciacionService();
  final AuthService _auth = AuthService();

  DepreciacionActivo? _datos;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await _service.tabla(widget.activoId);
      if (!mounted) return;
      setState(() {
        _datos = d;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    return Scaffold(
      appBar: barra(d?.resumen.codigo ?? 'Depreciación del activo'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null) BannerMensaje(_error!),
          if (_cargando) const Cargando(),
          if (d != null) ...[
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.resumen.codigo} · ${d.resumen.nombre}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(d.resumen.categoria, style: estiloMuted),
                  if (_auth.hasPermission('ACTIVOS_LEER'))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ActivoDetalleScreen(activoId: d.resumen.activoId)),
                        ),
                        icon: const Icon(Icons.qr_code_2, size: 18),
                        label: const Text('Ver ficha'),
                      ),
                    ),
                ],
              ),
            ),
            if (!d.resumen.depreciable) BannerMensaje(d.resumen.observacion ?? 'El activo no se deprecia.', tipo: TipoBanner.aviso),
            GrillaKpi(
              items: [
                TarjetaKpi(etiquetaKpi: 'Valor de adquisición', valor: formatoBs(d.resumen.valorAdquisicion)),
                TarjetaKpi(etiquetaKpi: 'Valor residual', valor: formatoBs(d.resumen.valorResidual)),
                if (d.resumen.depreciable)
                  TarjetaKpi(etiquetaKpi: 'Depreciación mensual', valor: formatoBs(d.resumen.depreciacionMensual)),
                TarjetaKpi(etiquetaKpi: 'Depreciación acumulada', valor: formatoBs(d.resumen.depreciacionAcumulada)),
                TarjetaKpi(etiquetaKpi: 'Valor en libros', valor: formatoBs(d.resumen.valorEnLibros), tono: TonoKpi.bien),
              ],
            ),
            if (d.resumen.depreciable)
              TarjetaSeccion(
                titulo: 'Tabla de depreciación (línea recta)',
                hijos: [TablaDepreciacion(d.filas)],
              ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================================
// Editar parametros de una categoria
// ======================================================================================

class _FormCategoria extends StatefulWidget {
  final Categoria categoria;

  const _FormCategoria({required this.categoria});

  @override
  State<_FormCategoria> createState() => _FormCategoriaState();
}

class _FormCategoriaState extends State<_FormCategoria> {
  final CategoriaService _service = CategoriaService();
  final TextEditingController _vidaCtrl = TextEditingController();
  final TextEditingController _pctCtrl = TextEditingController();

  bool _depreciable = true;
  String _metodo = 'LINEA_RECTA';
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.categoria;
    _depreciable = c.depreciable;
    _vidaCtrl.text = c.vidaUtil == null ? '' : c.vidaUtil.toString();
    _pctCtrl.text = formatoPorcentaje(c.valorResidualPct);
    final metodo = c.metodoDepreciacion;
    _metodo = (metodo == null || metodo.isEmpty) ? 'LINEA_RECTA' : metodo;
  }

  @override
  void dispose() {
    _vidaCtrl.dispose();
    _pctCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final vida = int.tryParse(_vidaCtrl.text.trim());
    if (_depreciable && (vida == null || vida < 1)) {
      setState(() => _error = 'Indica la vida útil (en años) de una categoría depreciable.');
      return;
    }
    final pct = leerNumero(_pctCtrl.text) ?? 0;
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      await _service.actualizar(
        widget.categoria.id,
        nombre: widget.categoria.nombre,
        depreciable: _depreciable,
        vidaUtil: _depreciable ? vida : null,
        valorResidualPct: pct,
        metodoDepreciacion: _metodo,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e, 'No se pudieron guardar los parámetros.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DEPRECIACIÓN', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          Text(widget.categoria.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 10),
          if (_error != null) BannerMensaje(_error!),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('La categoría se deprecia'),
            value: _depreciable,
            onChanged: (v) => setState(() => _depreciable = v),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _vidaCtrl,
            enabled: _depreciable,
            keyboardType: TextInputType.number,
            decoration: decoracion('Vida útil (años)', ayuda: 'Entre 1 y 100 años.'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pctCtrl,
            enabled: _depreciable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoracion('Valor residual (%)', ayuda: 'Entre 0 y 100.'),
          ),
          const SizedBox(height: 12),
          CampoSeleccion<String>(
            etiquetaCampo: 'Método',
            valor: _metodo,
            opciones: const [OpcionSeleccion<String>('LINEA_RECTA', 'Línea recta')],
            onChanged: (v) => setState(() => _metodo = v ?? 'LINEA_RECTA'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando...' : 'Guardar parámetros'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
