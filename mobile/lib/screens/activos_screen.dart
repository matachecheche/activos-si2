import 'package:flutter/material.dart';
import '../models/activo.dart';
import '../models/categoria.dart';
import '../services/activo_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/categoria_service.dart';
import '../widgets/comunes.dart';
import 'activo_detalle_screen.dart';
import 'activo_form_screen.dart';
import 'estado_util.dart';
import 'navegacion.dart';

/// HU-02 / HU-05: lista de activos con busqueda, filtros, apertura por codigo (QR), alta y edicion.
class ActivosScreen extends StatefulWidget {
  const ActivosScreen({super.key});

  @override
  State<ActivosScreen> createState() => _ActivosScreenState();
}

class _ActivosScreenState extends State<ActivosScreen> {
  final ActivoService _activoService = ActivoService();
  final CategoriaService _categoriaService = CategoriaService();
  final AuthService _auth = AuthService();
  final TextEditingController _codigoCtrl = TextEditingController();
  final TextEditingController _filtroCtrl = TextEditingController();

  List<Activo> _activos = <Activo>[];
  List<Categoria> _categorias = <Categoria>[];
  bool _cargando = true;
  String? _error;
  String? _mensaje;
  String? _filtroEstado;
  int? _filtroCategoria;

  bool get _puedeCrear => _auth.hasPermission('ACTIVOS_CREAR');
  bool get _puedeEditar => _auth.hasPermission('ACTIVOS_EDITAR');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _filtroCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final activos = await _activoService.listar();
      if (!mounted) return;
      setState(() {
        _activos = activos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudieron cargar los activos.');
      });
    }
    try {
      final categorias = await _categoriaService.listar();
      if (!mounted) return;
      setState(() => _categorias = categorias);
    } catch (_) {
      // El formulario y el filtro funcionan sin categorias; se reintenta al recargar.
    }
  }

  List<Activo> get _filtrados {
    final q = _filtroCtrl.text.trim().toLowerCase();
    return _activos.where((a) {
      if (_filtroEstado != null && a.estado != _filtroEstado) return false;
      if (_filtroCategoria != null && a.categoriaId != _filtroCategoria) return false;
      if (q.isEmpty) return true;
      final responsable = a.responsable?.nombre.toLowerCase() ?? '';
      return a.codigo.toLowerCase().contains(q) || a.nombre.toLowerCase().contains(q) || responsable.contains(q);
    }).toList();
  }

  Future<void> _abrirFicha(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActivoDetalleScreen(activoId: id)));
    if (mounted) _cargar();
  }

  /// HU-05: el codigo leido del QR (o escrito) abre directamente la ficha del activo.
  Future<void> _abrirPorCodigo() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) {
      setState(() => _error = 'Ingresa el código del activo (por ejemplo ACT-2026-0001).');
      return;
    }
    setState(() {
      _error = null;
      _mensaje = null;
    });
    try {
      final activo = await _activoService.porCodigo(codigo);
      if (!mounted) return;
      _codigoCtrl.clear();
      await _abrirFicha(activo.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'No existe un activo con ese código.'));
    }
  }

  Future<void> _nuevo() async {
    setState(() {
      _error = null;
      _mensaje = null;
    });
    final guardado = await Navigator.of(context).push<Activo>(
      MaterialPageRoute(builder: (_) => ActivoFormScreen(categorias: _categorias)),
    );
    if (guardado != null && mounted) {
      setState(() => _mensaje = 'Activo ${guardado.codigo} guardado correctamente.');
      _cargar();
    }
  }

  /// HU-02: solo se edita un activo sin movimientos asociados.
  Future<void> _editar(Activo activo) async {
    setState(() {
      _error = null;
      _mensaje = null;
    });
    try {
      final detalle = await _activoService.obtener(activo.id);
      if (!mounted) return;
      if (detalle.editable == false) {
        setState(() => _error =
            'El activo ${detalle.codigo} ya tiene movimientos asociados (asignaciones, estados o mantenimientos) y no puede editarse.');
        return;
      }
      final guardado = await Navigator.of(context).push<Activo>(
        MaterialPageRoute(builder: (_) => ActivoFormScreen(activo: detalle, categorias: _categorias)),
      );
      if (guardado != null && mounted) {
        setState(() => _mensaje = 'Activo ${guardado.codigo} guardado correctamente.');
        _cargar();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  Widget _barraCodigo() {
    return TarjetaSeccion(
      titulo: 'Abrir por código o QR',
      hijos: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codigoCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _abrirPorCodigo(),
                decoration: decoracion('Código del activo', sugerencia: 'ACT-2026-0001'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _abrirPorCodigo, child: const Text('Abrir ficha')),
          ],
        ),
      ],
    );
  }

  Widget _filtros() {
    return TarjetaSeccion(
      hijos: [
        TextField(
          controller: _filtroCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Buscar por código, nombre o responsable',
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _filtroCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _filtroCtrl.clear()),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        CampoSeleccion<String>(
          etiquetaCampo: 'Estado',
          valor: _filtroEstado,
          textoLimpiar: 'Todos los estados',
          opciones: [for (final e in estadosActivo) OpcionSeleccion<String>(e, etiqueta(e))],
          onChanged: (v) => setState(() => _filtroEstado = v),
        ),
        const SizedBox(height: 10),
        CampoSeleccion<int>(
          etiquetaCampo: 'Categoría',
          valor: _filtroCategoria,
          textoLimpiar: 'Todas las categorías',
          opciones: [for (final c in _categorias) OpcionSeleccion<int>(c.id, c.nombre)],
          onChanged: (v) => setState(() => _filtroCategoria = v),
        ),
      ],
    );
  }

  Widget _tarjeta(Activo a) {
    final responsable = a.responsable?.nombre;
    final ubicacion = a.ubicacion?.nombre;
    return Tarjeta(
      onTap: () => _abrirFicha(a.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(a.codigo, style: estiloMono)),
              insigniaDe(a.estado, texto: a.estadoEtiqueta),
            ],
          ),
          const SizedBox(height: 4),
          Text(a.nombre, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${a.categoriaNombre.isEmpty ? 'Sin categoría' : a.categoriaNombre} · ${formatoBs(a.valor)}', style: estiloMuted),
          if (responsable != null) Text('Responsable: $responsable', style: estiloMuted),
          if (ubicacion != null) Text('Ubicación: $ubicacion', style: estiloMuted),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _abrirFicha(a.id),
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: const Text('Ficha'),
              ),
              if (_puedeEditar)
                TextButton.icon(
                  onPressed: () => _editar(a),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Scaffold(
      appBar: barraModulo('Activos fijos', '/activos', acciones: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
      ]),
      drawer: const MenuLateral(rutaActual: '/activos'),
      floatingActionButton: _puedeCrear
          ? FloatingActionButton.extended(
              onPressed: _nuevo,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo activo'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            const Subtitulo('Registro, asignación, estado, depreciación y etiquetas QR de los activos de la universidad.'),
            if (_error != null) BannerMensaje(_error!),
            if (_mensaje != null) BannerMensaje(_mensaje!, tipo: TipoBanner.ok),
            _barraCodigo(),
            _filtros(),
            if (_cargando)
              const Cargando()
            else if (filtrados.isEmpty)
              const MensajeVacio('No hay activos que coincidan con la búsqueda.')
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${filtrados.length} activo(s)', style: estiloMuted),
              ),
              for (final a in filtrados) _tarjeta(a),
            ],
          ],
        ),
      ),
    );
  }
}
