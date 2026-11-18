import 'package:flutter/material.dart';
import '../models/activo.dart';
import '../models/presupuesto.dart';
import '../services/activo_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/presupuesto_service.dart';
import '../widgets/comunes.dart';
import 'estado_util.dart';

/// HU-09 (partidas, aprobacion, cierre) y HU-10 (ejecucion y seguimiento) de un presupuesto.
class PresupuestoDetalleScreen extends StatefulWidget {
  final int presupuestoId;

  const PresupuestoDetalleScreen({super.key, required this.presupuestoId});

  @override
  State<PresupuestoDetalleScreen> createState() => _PresupuestoDetalleScreenState();
}

class _PresupuestoDetalleScreenState extends State<PresupuestoDetalleScreen> {
  final PresupuestoService _service = PresupuestoService();
  final AuthService _auth = AuthService();

  Presupuesto? _presupuesto;
  List<Partida> _partidas = <Partida>[];
  List<Ejecucion> _ejecuciones = <Ejecucion>[];
  List<Activo> _activos = <Activo>[];
  int _pestana = 0; // 0 = partidas y seguimiento, 1 = compromisos y ejecucion
  String? _error;
  String? _ok;
  bool _cargando = true;

  bool get _esBorrador => _presupuesto?.estado == 'BORRADOR';
  bool get _esAprobado => _presupuesto?.estado == 'APROBADO';
  bool get _puedeEditar => _auth.hasPermission('PRESUPUESTO_EDITAR');
  bool get _puedeCrear => _auth.hasPermission('PRESUPUESTO_CREAR');

  @override
  void initState() {
    super.initState();
    _cargar();
    if (_auth.hasPermission('ACTIVOS_LEER')) _cargarActivos();
  }

  Future<void> _cargarActivos() async {
    try {
      final activos = await ActivoService().listar();
      if (!mounted) return;
      setState(() => _activos = activos);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activos = <Activo>[]);
    }
  }

  Future<void> _cargar() async {
    try {
      final seguimiento = await _service.seguimiento(widget.presupuestoId);
      if (!mounted) return;
      setState(() {
        _presupuesto = seguimiento.presupuesto;
        _partidas = seguimiento.partidas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudo cargar el presupuesto.');
      });
    }
    try {
      final ejecuciones = await _service.ejecuciones(widget.presupuestoId);
      if (!mounted) return;
      setState(() => _ejecuciones = ejecuciones);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ejecuciones = <Ejecucion>[]);
    }
  }

  void _limpiar() {
    _error = null;
    _ok = null;
  }

  // ---------------- presupuesto ----------------

  Future<void> _aprobar() async {
    final p = _presupuesto;
    if (p == null) return;
    final seguro = await confirmar(
      context,
      '¿Aprobar el presupuesto? Después no podrá modificarse.',
      titulo: 'Aprobar presupuesto',
      textoSi: 'Aprobar',
    );
    if (!seguro || !mounted) return;
    setState(_limpiar);
    try {
      await _service.aprobar(p.id);
      if (!mounted) return;
      setState(() => _ok = 'Presupuesto aprobado. Ya se pueden registrar compromisos y ejecuciones.');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  Future<void> _cerrar() async {
    final p = _presupuesto;
    if (p == null) return;
    final seguro = await confirmar(
      context,
      '¿Cerrar el presupuesto al finalizar la gestión? Ya no admitirá operaciones.',
      titulo: 'Cerrar gestión',
      textoSi: 'Cerrar',
    );
    if (!seguro || !mounted) return;
    setState(_limpiar);
    try {
      await _service.cerrar(p.id);
      if (!mounted) return;
      setState(() => _ok = 'Presupuesto cerrado.');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  Future<void> _cambiarMonto() async {
    final p = _presupuesto;
    if (p == null) return;
    final guardado = await abrirHoja<bool>(context, _FormMonto(presupuesto: p));
    if (guardado == true && mounted) {
      setState(() {
        _error = null;
        _ok = 'Monto aprobado actualizado.';
      });
      _cargar();
    }
  }

  // ---------------- partidas ----------------

  Future<void> _formPartida([Partida? editando]) async {
    final p = _presupuesto;
    if (p == null) return;
    final guardado = await abrirHoja<bool>(context, _FormPartida(presupuesto: p, editando: editando));
    if (guardado == true && mounted) {
      setState(() {
        _error = null;
        _ok = 'Partida guardada.';
      });
      _cargar();
    }
  }

  Future<void> _eliminarPartida(Partida pa) async {
    final p = _presupuesto;
    if (p == null) return;
    final seguro = await confirmar(
      context,
      '¿Eliminar la partida ${pa.codigo}?',
      titulo: 'Eliminar partida',
      textoSi: 'Eliminar',
      peligro: true,
    );
    if (!seguro || !mounted) return;
    setState(_limpiar);
    try {
      await _service.eliminarPartida(p.id, pa.id);
      if (!mounted) return;
      setState(() => _ok = 'Partida eliminada.');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  // ---------------- interfaz ----------------

  Widget _encabezado(Presupuesto p) {
    final aprobacion = p.fechaAprobacion;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GESTIÓN ${p.gestion}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          Text(p.areaNombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              insigniaDe(p.estado),
              if (aprobacion != null) Text('aprobado el ${formatoFechaHora(aprobacion)} por ${p.aprobador ?? '-'}', style: estiloMuted),
            ],
          ),
          if (_puedeEditar && (_esBorrador || _esAprobado))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_esBorrador)
                    OutlinedButton(onPressed: _cambiarMonto, child: const Text('Cambiar monto aprobado')),
                  if (_esBorrador)
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                      onPressed: _aprobar,
                      child: const Text('Aprobar presupuesto'),
                    ),
                  if (_esAprobado) OutlinedButton(onPressed: _cerrar, child: const Text('Cerrar gestión')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpis(Presupuesto p) {
    return GrillaKpi(
      items: [
        TarjetaKpi(etiquetaKpi: 'Monto aprobado', valor: formatoBs(p.montoAprobado)),
        TarjetaKpi(etiquetaKpi: 'Planificado (partidas)', valor: formatoBs(p.montoPlanificado)),
        TarjetaKpi(etiquetaKpi: 'Sin distribuir', valor: formatoBs(p.sinDistribuir)),
        TarjetaKpi(etiquetaKpi: 'Comprometido', valor: formatoBs(p.comprometido), tono: TonoKpi.alerta),
        TarjetaKpi(etiquetaKpi: 'Ejecutado', valor: '${formatoBs(p.ejecutado)} (${formatoPorcentaje(p.porcentajeEjecucion)} %)'),
        TarjetaKpi(etiquetaKpi: 'Saldo disponible', valor: formatoBs(p.saldoDisponible), tono: TonoKpi.bien),
      ],
    );
  }

  Widget _selectorPestana() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: const Text('Partidas y seguimiento'),
            selected: _pestana == 0,
            onSelected: (_) => setState(() => _pestana = 0),
          ),
          ChoiceChip(
            label: const Text('Compromisos y ejecución'),
            selected: _pestana == 1,
            onSelected: (_) => setState(() => _pestana = 1),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPartida(Partida pa) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pa.codigo, style: estiloMono),
          Text(pa.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          BarraEjecucion(pa.porcentajeEjecucion),
          const SizedBox(height: 6),
          Text('Planificado: ${formatoBs(pa.montoPlanificado)}', style: estiloMuted),
          Text('Comprometido: ${formatoBs(pa.comprometido)}', style: estiloMuted),
          Text('Ejecutado: ${formatoBs(pa.ejecutado)}', style: estiloMuted),
          Text('Saldo disponible: ${formatoBs(pa.saldoDisponible)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_esBorrador && _puedeEditar)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => _formPartida(pa), child: const Text('Editar')),
                TextButton(
                  onPressed: () => _eliminarPartida(pa),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _panelPartidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaSeccion(
          titulo: 'Partidas presupuestarias',
          accion: (_esBorrador && _puedeCrear)
              ? FilledButton.icon(
                  onPressed: () => _formPartida(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva partida'),
                )
              : null,
          hijos: [
            if (_partidas.isEmpty)
              MensajeVacio('Todavía no hay partidas. ${_esBorrador ? 'Agrega las partidas y luego aprueba el presupuesto.' : ''}')
            else
              const Text('Planificado frente a lo comprometido y ejecutado en cada partida.', style: estiloMuted),
            if (_esBorrador) ...[
              const SizedBox(height: 8),
              const Text(
                'La suma de las partidas no puede superar el monto aprobado. Un presupuesto aprobado o cerrado no puede modificarse.',
                style: estiloMuted,
              ),
            ],
          ],
        ),
        for (final pa in _partidas) _tarjetaPartida(pa),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _presupuesto;
    return Scaffold(
      appBar: barra(p == null ? 'Presupuesto' : 'Presupuesto ${p.gestion}'),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_error != null) BannerMensaje(_error!),
            if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
            if (_cargando) const Cargando(),
            if (p != null) ...[
              _encabezado(p),
              _kpis(p),
              _selectorPestana(),
              Visibility(visible: _pestana == 0, maintainState: true, child: _panelPartidas()),
              Visibility(
                visible: _pestana == 1,
                maintainState: true,
                child: _PanelEjecucion(
                  presupuesto: p,
                  partidas: _partidas,
                  ejecuciones: _ejecuciones,
                  activos: _activos,
                  esAprobado: _esAprobado,
                  puedeRegistrar: _puedeCrear,
                  alRegistrar: (mensaje) {
                    setState(() {
                      _error = null;
                      _ok = mensaje;
                    });
                    _cargar();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================================================================================
// HU-10: compromisos y ejecucion
// ======================================================================================

class _PanelEjecucion extends StatefulWidget {
  final Presupuesto presupuesto;
  final List<Partida> partidas;
  final List<Ejecucion> ejecuciones;
  final List<Activo> activos;
  final bool esAprobado;
  final bool puedeRegistrar;
  final ValueChanged<String> alRegistrar;

  const _PanelEjecucion({
    required this.presupuesto,
    required this.partidas,
    required this.ejecuciones,
    required this.activos,
    required this.esAprobado,
    required this.puedeRegistrar,
    required this.alRegistrar,
  });

  @override
  State<_PanelEjecucion> createState() => _PanelEjecucionState();
}

class _PanelEjecucionState extends State<_PanelEjecucion> {
  final PresupuestoService _service = PresupuestoService();
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _conceptoCtrl = TextEditingController();

  int? _partidaId;
  String _tipo = 'EJECUCION';
  String? _fecha = hoyIso();
  int? _activoId;
  int? _compromisoId;
  String? _error;
  bool _enviando = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    super.dispose();
  }

  Partida? get _partidaSeleccionada {
    for (final p in widget.partidas) {
      if (p.id == _partidaId) return p;
    }
    return null;
  }

  /// Compromisos de la partida elegida que todavia no fueron ejecutados.
  List<Ejecucion> get _compromisosPendientes {
    return widget.ejecuciones.where((e) => e.tipo == 'COMPROMISO' && !e.liberado && e.partidaId == _partidaId).toList();
  }

  void _alElegirCompromiso(int? id) {
    setState(() => _compromisoId = id);
    if (id == null) return;
    for (final c in _compromisosPendientes) {
      if (c.id == id) {
        if (leerNumero(_montoCtrl.text) == null) _montoCtrl.text = numeroParaEditar(c.monto);
        if (_conceptoCtrl.text.trim().isEmpty) _conceptoCtrl.text = c.concepto;
        break;
      }
    }
  }

  Future<void> _registrar() async {
    final partidaId = _partidaId;
    final fecha = _fecha;
    final concepto = _conceptoCtrl.text.trim();
    final monto = leerNumero(_montoCtrl.text);
    if (partidaId == null || fecha == null || fecha.isEmpty || concepto.isEmpty || monto == null || monto <= 0) {
      setState(() => _error = 'Completa la partida, la fecha, el concepto y un monto mayor a cero.');
      return;
    }
    final tipo = _tipo;
    setState(() {
      _error = null;
      _enviando = true;
    });
    try {
      await _service.registrarEjecucion(
        partidaId: partidaId,
        tipo: tipo,
        fecha: fecha,
        concepto: concepto,
        monto: monto,
        activoId: _activoId,
        compromisoId: tipo == 'EJECUCION' ? _compromisoId : null,
      );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _partidaId = null;
        _tipo = 'EJECUCION';
        _fecha = hoyIso();
        _activoId = null;
        _compromisoId = null;
        _montoCtrl.clear();
        _conceptoCtrl.clear();
      });
      widget.alRegistrar(tipo == 'COMPROMISO' ? 'Compromiso registrado.' : 'Ejecución registrada.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = mensajeError(e, 'No se pudo registrar la operación.');
      });
    }
  }

  Widget _formulario() {
    final seleccionada = _partidaSeleccionada;
    return TarjetaSeccion(
      titulo: 'Registrar compromiso o ejecución',
      hijos: [
        if (_error != null) BannerMensaje(_error!),
        CampoSeleccion<int>(
          etiquetaCampo: 'Partida *',
          valor: _partidaId,
          opciones: [
            for (final pa in widget.partidas)
              OpcionSeleccion<int>(pa.id, '${pa.codigo} — ${pa.nombre} (saldo ${formatoMonto(pa.saldoDisponible)})'),
          ],
          onChanged: (v) => setState(() {
            _partidaId = v;
            _compromisoId = null;
          }),
        ),
        const SizedBox(height: 12),
        const Text('Tipo *', style: estiloMuted),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Compromiso (reserva saldo)'),
              selected: _tipo == 'COMPROMISO',
              onSelected: (_) => setState(() {
                _tipo = 'COMPROMISO';
                _compromisoId = null;
              }),
            ),
            ChoiceChip(
              label: const Text('Ejecución (gasto real)'),
              selected: _tipo == 'EJECUCION',
              onSelected: (_) => setState(() => _tipo = 'EJECUCION'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CampoFecha(
          etiquetaCampo: 'Fecha *',
          valor: _fecha,
          onChanged: (v) => setState(() => _fecha = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _montoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoracion(
            'Monto (Bs) *',
            ayuda: seleccionada != null ? 'Saldo disponible de la partida: ${formatoBs(seleccionada.saldoDisponible)}' : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _conceptoCtrl,
          maxLength: 200,
          decoration: decoracion('Concepto *'),
        ),
        if (_tipo == 'EJECUCION') ...[
          const SizedBox(height: 6),
          CampoSeleccion<int>(
            etiquetaCampo: 'Compromiso previo (opcional)',
            valor: _compromisoId,
            textoLimpiar: 'Sin compromiso',
            ayuda: 'Al ejecutarlo, el compromiso se libera y su monto no se duplica en el saldo.',
            opciones: [
              for (final c in _compromisosPendientes) OpcionSeleccion<int>(c.id, '#${c.id} — ${c.concepto} (Bs ${formatoMonto(c.monto)})'),
            ],
            onChanged: _alElegirCompromiso,
          ),
        ],
        if (widget.activos.isNotEmpty) ...[
          const SizedBox(height: 12),
          CampoSeleccion<int>(
            etiquetaCampo: 'Activo adquirido (opcional)',
            valor: _activoId,
            textoLimpiar: 'Ninguno',
            opciones: [for (final a in widget.activos) OpcionSeleccion<int>(a.id, '${a.codigo} — ${a.nombre}')],
            onChanged: (v) => setState(() => _activoId = v),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _enviando ? null : _registrar,
          child: Text(_enviando ? 'Registrando...' : 'Registrar'),
        ),
      ],
    );
  }

  Widget _filaMovimiento(Ejecucion e) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: colorBorde))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${formatoFecha(e.fecha)} · ${e.partidaCodigo}', style: estiloMuted)),
              Text(formatoBs(e.monto), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              insigniaDe(e.tipo),
              if (e.liberado) const Text('· liberado', style: estiloMuted),
              if (e.compromisoId != null) Text('· de #${e.compromisoId}', style: estiloMuted),
            ],
          ),
          const SizedBox(height: 3),
          Text(e.concepto),
          if (e.activoCodigo != null && e.activoCodigo!.isNotEmpty) Text('Activo: ${e.activoCodigo}', style: estiloMuted),
          Text('Registró: ${e.usuario ?? '-'}', style: estiloMuted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.esAprobado && widget.puedeRegistrar) _formulario(),
        if (!widget.esAprobado)
          BannerMensaje(
            'Solo se pueden registrar compromisos y ejecuciones en presupuestos aprobados (estado actual: ${etiqueta(widget.presupuesto.estado)}).',
            tipo: TipoBanner.aviso,
          ),
        TarjetaSeccion(
          titulo: 'Movimientos',
          hijos: [
            if (widget.ejecuciones.isEmpty)
              const MensajeVacio('Sin movimientos registrados.')
            else
              for (final e in widget.ejecuciones) _filaMovimiento(e),
          ],
        ),
      ],
    );
  }
}

// ======================================================================================
// Monto aprobado
// ======================================================================================

class _FormMonto extends StatefulWidget {
  final Presupuesto presupuesto;

  const _FormMonto({required this.presupuesto});

  @override
  State<_FormMonto> createState() => _FormMontoState();
}

class _FormMontoState extends State<_FormMonto> {
  final PresupuestoService _service = PresupuestoService();
  final TextEditingController _montoCtrl = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _montoCtrl.text = numeroParaEditar(widget.presupuesto.montoAprobado);
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = leerNumero(_montoCtrl.text);
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Indica un monto mayor a cero.');
      return;
    }
    final p = widget.presupuesto;
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      await _service.actualizar(p.id, areaId: p.areaId, gestion: p.gestion, montoAprobado: monto);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e);
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
          const Text('Monto aprobado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoracion('Monto aprobado (Bs)'),
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
                  child: Text(_guardando ? 'Guardando...' : 'Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======================================================================================
// Partida (alta y edicion)
// ======================================================================================

class _FormPartida extends StatefulWidget {
  final Presupuesto presupuesto;
  final Partida? editando;

  const _FormPartida({required this.presupuesto, this.editando});

  @override
  State<_FormPartida> createState() => _FormPartidaState();
}

class _FormPartidaState extends State<_FormPartida> {
  final PresupuestoService _service = PresupuestoService();
  final TextEditingController _codigoCtrl = TextEditingController();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.editando;
    if (p != null) {
      _codigoCtrl.text = p.codigo;
      _nombreCtrl.text = p.nombre;
      _montoCtrl.text = numeroParaEditar(p.montoPlanificado);
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final codigo = _codigoCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();
    final monto = leerNumero(_montoCtrl.text);
    if (codigo.isEmpty || nombre.isEmpty || monto == null || monto <= 0) {
      setState(() => _error = 'Completa el código, el nombre y un monto planificado mayor a cero.');
      return;
    }
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      final editando = widget.editando;
      if (editando == null) {
        await _service.crearPartida(widget.presupuesto.id, codigo: codigo, nombre: nombre, montoPlanificado: monto);
      } else {
        await _service.actualizarPartida(widget.presupuesto.id, editando.id, codigo: codigo, nombre: nombre, montoPlanificado: monto);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e, 'No se pudo guardar la partida.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando;
    final disponible = widget.presupuesto.sinDistribuir + (editando != null ? editando.montoPlanificado : 0);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('PARTIDA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          Text(editando != null ? 'Editar partida' : 'Nueva partida', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          TextField(
            controller: _codigoCtrl,
            maxLength: 30,
            decoration: decoracion('Código *', sugerencia: 'Ej.: 43100'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoracion('Monto planificado (Bs) *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nombreCtrl,
            maxLength: 150,
            decoration: decoracion('Nombre *', sugerencia: 'Ej.: Equipos de computación'),
          ),
          const SizedBox(height: 4),
          Text('Disponible para distribuir: ${formatoBs(disponible)}', style: estiloMuted),
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
                  child: Text(_guardando ? 'Guardando...' : 'Guardar partida'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
