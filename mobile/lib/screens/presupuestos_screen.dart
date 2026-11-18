import 'package:flutter/material.dart';
import '../models/presupuesto.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/presupuesto_service.dart';
import '../widgets/comunes.dart';
import 'estado_util.dart';
import 'navegacion.dart';
import 'presupuesto_detalle_screen.dart';

/// HU-09 / HU-10: presupuesto anual por gestion y area, con seguimiento de lo planificado frente a lo ejecutado.
class PresupuestosScreen extends StatefulWidget {
  const PresupuestosScreen({super.key});

  @override
  State<PresupuestosScreen> createState() => _PresupuestosScreenState();
}

class _PresupuestosScreenState extends State<PresupuestosScreen> {
  final PresupuestoService _service = PresupuestoService();
  final AuthService _auth = AuthService();
  final TextEditingController _gestionCtrl = TextEditingController();

  List<Presupuesto> _presupuestos = <Presupuesto>[];
  List<Area> _areas = <Area>[];
  int? _filtroArea;
  String? _error;
  String? _ok;
  bool _cargando = true;

  bool get _puedeCrear => _auth.hasPermission('PRESUPUESTO_CREAR');
  bool get _puedeEliminar => _auth.hasPermission('PRESUPUESTO_ELIMINAR');

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarAreas();
  }

  @override
  void dispose() {
    _gestionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAreas() async {
    try {
      final areas = await _service.areas();
      if (!mounted) return;
      setState(() => _areas = areas.where((a) => a.activo).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _areas = <Area>[]);
    }
  }

  Future<void> _cargar() async {
    try {
      final gestion = int.tryParse(_gestionCtrl.text.trim());
      final lista = await _service.listar(gestion: gestion, areaId: _filtroArea);
      if (!mounted) return;
      setState(() {
        _presupuestos = lista;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudieron cargar los presupuestos.');
      });
    }
  }

  void _limpiarFiltros() {
    _gestionCtrl.clear();
    setState(() => _filtroArea = null);
    _cargar();
  }

  Future<void> _nuevo() async {
    setState(() {
      _error = null;
      _ok = null;
    });
    final creado = await abrirHoja<bool>(context, _FormPresupuesto(areas: _areas));
    if (!mounted) return;
    _cargarAreas();
    if (creado == true) {
      setState(() => _ok = 'Presupuesto creado en estado Borrador. Agrega sus partidas y apruébalo.');
      _cargar();
    }
  }

  Future<void> _eliminar(Presupuesto p) async {
    final seguro = await confirmar(
      context,
      '¿Eliminar el borrador de ${p.areaNombre} ${p.gestion}?',
      titulo: 'Eliminar presupuesto',
      textoSi: 'Eliminar',
      peligro: true,
    );
    if (!seguro || !mounted) return;
    setState(() {
      _error = null;
      _ok = null;
    });
    try {
      await _service.eliminar(p.id);
      if (!mounted) return;
      setState(() => _ok = 'Presupuesto eliminado.');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  Future<void> _abrir(Presupuesto p) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PresupuestoDetalleScreen(presupuestoId: p.id)));
    if (mounted) _cargar();
  }

  Widget _tarjeta(Presupuesto p) {
    return Tarjeta(
      onTap: () => _abrir(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GESTIÓN ${p.gestion}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF1769E0))),
                    Text(p.areaNombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              insigniaDe(p.estado),
            ],
          ),
          const SizedBox(height: 8),
          BarraEjecucion(p.porcentajeEjecucion),
          const SizedBox(height: 8),
          Text('Monto aprobado: ${formatoBs(p.montoAprobado)}', style: estiloMuted),
          Text('Planificado: ${formatoBs(p.montoPlanificado)}', style: estiloMuted),
          Text('Ejecutado: ${formatoBs(p.ejecutado)}', style: estiloMuted),
          Text('Saldo disponible: ${formatoBs(p.saldoDisponible)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => _abrir(p), child: const Text('Abrir')),
              if (p.estado == 'BORRADOR' && _puedeEliminar)
                TextButton(
                  onPressed: () => _eliminar(p),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  child: const Text('Eliminar'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraModulo('Presupuestos', '/presupuestos', acciones: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
      ]),
      drawer: const MenuLateral(rutaActual: '/presupuestos'),
      floatingActionButton: _puedeCrear
          ? FloatingActionButton.extended(
              onPressed: _nuevo,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo presupuesto'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await _cargar();
          await _cargarAreas();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            const Subtitulo('Presupuesto anual por gestión y área, con seguimiento de lo planificado frente a lo ejecutado.'),
            if (_error != null) BannerMensaje(_error!),
            if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
            TarjetaSeccion(
              hijos: [
                TextField(
                  controller: _gestionCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _cargar(),
                  onChanged: (v) {
                    if (v.isEmpty || v.length == 4) _cargar();
                  },
                  decoration: decoracion('Gestión', sugerencia: 'ej. 2026'),
                ),
                const SizedBox(height: 10),
                CampoSeleccion<int>(
                  etiquetaCampo: 'Área',
                  valor: _filtroArea,
                  textoLimpiar: 'Todas las áreas',
                  opciones: [for (final a in _areas) OpcionSeleccion<int>(a.id, a.nombre)],
                  onChanged: (v) {
                    setState(() => _filtroArea = v);
                    _cargar();
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _limpiarFiltros, child: const Text('Limpiar')),
                ),
              ],
            ),
            if (_cargando)
              const Cargando()
            else if (_presupuestos.isEmpty)
              const MensajeVacio('No hay presupuestos para los filtros seleccionados.')
            else
              for (final p in _presupuestos) _tarjeta(p),
          ],
        ),
      ),
    );
  }
}

// ======================================================================================
// Nuevo presupuesto
// ======================================================================================

class _FormPresupuesto extends StatefulWidget {
  final List<Area> areas;

  const _FormPresupuesto({required this.areas});

  @override
  State<_FormPresupuesto> createState() => _FormPresupuestoState();
}

class _FormPresupuestoState extends State<_FormPresupuesto> {
  final PresupuestoService _service = PresupuestoService();
  final TextEditingController _gestionCtrl = TextEditingController(text: gestionActual().toString());
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _nuevaAreaCtrl = TextEditingController();

  List<Area> _areas = <Area>[];
  int? _areaId;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _areas = List<Area>.from(widget.areas);
    if (_areas.isNotEmpty) _areaId = _areas.first.id;
  }

  @override
  void dispose() {
    _gestionCtrl.dispose();
    _montoCtrl.dispose();
    _nuevaAreaCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearArea() async {
    final nombre = _nuevaAreaCtrl.text.trim();
    if (nombre.isEmpty) return;
    try {
      final area = await _service.crearArea(nombre);
      if (!mounted) return;
      setState(() {
        _areas = [..._areas, area];
        _areaId = area.id;
        _nuevaAreaCtrl.clear();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  Future<void> _guardar() async {
    final areaId = _areaId;
    final gestion = int.tryParse(_gestionCtrl.text.trim());
    final monto = leerNumero(_montoCtrl.text);
    if (areaId == null || gestion == null || monto == null || monto <= 0) {
      setState(() => _error = 'Completa el área, la gestión y un monto aprobado mayor a cero.');
      return;
    }
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      await _service.crear(areaId: areaId, gestion: gestion, montoAprobado: monto);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e, 'No se pudo crear el presupuesto.');
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
          const Text('PRESUPUESTO', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          const Text('Nuevo presupuesto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          CampoSeleccion<int>(
            etiquetaCampo: 'Área *',
            valor: _areaId,
            opciones: [for (final a in _areas) OpcionSeleccion<int>(a.id, a.nombre)],
            onChanged: (v) => setState(() => _areaId = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuevaAreaCtrl,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: '¿No está el área? Nueva área',
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _crearArea, child: const Text('Agregar')),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _gestionCtrl,
            keyboardType: TextInputType.number,
            decoration: decoracion('Gestión *', ayuda: 'Entre 2000 y 2100.'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoracion('Monto aprobado (Bs) *'),
          ),
          const SizedBox(height: 10),
          const Text('Un área solo puede tener un presupuesto por gestión. Se crea como Borrador.', style: estiloMuted),
          const SizedBox(height: 14),
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
                  child: Text(_guardando ? 'Creando...' : 'Crear presupuesto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
