import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activo.dart';
import '../models/ficha.dart';
import '../services/activo_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/mantenimiento_service.dart';
import '../widgets/comunes.dart';
import 'activo_detalle_screen.dart';
import 'estado_util.dart';
import 'navegacion.dart';

/// HU-08: mantenimientos preventivos y correctivos (programar, iniciar, finalizar, reprogramar y cancelar).
class MantenimientosScreen extends StatefulWidget {
  /// Si se indica (desde la ficha del activo), se abre el formulario para programar con ese activo elegido.
  final int? activoIdInicial;

  const MantenimientosScreen({super.key, this.activoIdInicial});

  @override
  State<MantenimientosScreen> createState() => _MantenimientosScreenState();
}

class _MantenimientosScreenState extends State<MantenimientosScreen> {
  final MantenimientoService _service = MantenimientoService();
  final ActivoService _activoService = ActivoService();
  final AuthService _auth = AuthService();
  final TextEditingController _filtroCtrl = TextEditingController();

  List<Mantenimiento> _items = <Mantenimiento>[];
  AlertasMantenimiento _alertas = AlertasMantenimiento(proximos: <Mantenimiento>[], vencidos: <Mantenimiento>[]);
  List<Activo> _activos = <Activo>[];
  String? _filtroEstado;
  String? _error;
  String? _ok;
  bool _cargando = true;

  bool get _puedeCrear => _auth.hasPermission('MANTENIMIENTO_CREAR');
  bool get _puedeEditar => _auth.hasPermission('MANTENIMIENTO_EDITAR');
  bool get _veActivos => _auth.hasPermission('ACTIVOS_LEER');

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarActivos();
  }

  @override
  void dispose() {
    _filtroCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarActivos() async {
    try {
      final todos = await _activoService.listar();
      if (!mounted) return;
      setState(() => _activos = todos.where((a) => a.estado != 'DADO_DE_BAJA').toList());
      final preseleccion = widget.activoIdInicial;
      if (preseleccion != null && _puedeCrear) _nuevo(preseleccion);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activos = <Activo>[]);
    }
  }

  Future<void> _cargar() async {
    try {
      final items = await _service.listar();
      if (!mounted) return;
      setState(() {
        _items = items;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudieron cargar los mantenimientos.');
      });
    }
    try {
      final alertas = await _service.alertas();
      if (!mounted) return;
      setState(() => _alertas = alertas);
    } catch (_) {
      // Las alertas son informativas: si fallan no se interrumpe la pantalla.
    }
  }

  List<Mantenimiento> get _filtrados {
    final t = _filtroCtrl.text.trim().toLowerCase();
    return _items.where((m) {
      if (_filtroEstado != null && m.estado != _filtroEstado) return false;
      if (t.isEmpty) return true;
      return m.activoCodigo.toLowerCase().contains(t) || m.activoNombre.toLowerCase().contains(t);
    }).toList();
  }

  void _limpiar() {
    _error = null;
    _ok = null;
  }

  Future<void> _nuevo([int? activoId]) async {
    setState(_limpiar);
    final guardado = await abrirHoja<bool>(context, _FormMantenimiento(activos: _activos, activoIdInicial: activoId));
    if (guardado == true && mounted) {
      setState(() => _ok = 'Mantenimiento guardado.');
      _cargar();
    }
  }

  Future<void> _reprogramar(Mantenimiento m) async {
    setState(_limpiar);
    final guardado = await abrirHoja<bool>(context, _FormMantenimiento(activos: _activos, editando: m));
    if (guardado == true && mounted) {
      setState(() => _ok = 'Mantenimiento guardado.');
      _cargar();
    }
  }

  Future<void> _iniciar(Mantenimiento m) async {
    setState(_limpiar);
    try {
      await _service.iniciar(m.id);
      if (!mounted) return;
      setState(() => _ok = 'Mantenimiento iniciado: ${m.activoCodigo} pasó a «En mantenimiento».');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'No se pudo iniciar el mantenimiento.'));
    }
  }

  Future<void> _finalizar(Mantenimiento m) async {
    setState(_limpiar);
    final hecho = await abrirHoja<bool>(context, _FormFinalizar(mantenimiento: m));
    if (hecho == true && mounted) {
      setState(() => _ok = 'Mantenimiento finalizado: ${m.activoCodigo} volvió a su estado previo.');
      _cargar();
    }
  }

  Future<void> _cancelar(Mantenimiento m) async {
    setState(_limpiar);
    final motivo = await pedirTexto(
      context,
      titulo: 'Cancelar mantenimiento',
      mensaje: '${m.activoCodigo} · ${m.activoNombre}',
      etiquetaCampo: 'Motivo (opcional)',
      textoConfirmar: 'Cancelar mantenimiento',
      textoVolver: 'Volver',
      peligro: true,
    );
    if (motivo == null || !mounted) return;
    try {
      await _service.cancelar(m.id, motivo);
      if (!mounted) return;
      setState(() => _ok = 'Mantenimiento cancelado.');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'No se pudo cancelar el mantenimiento.'));
    }
  }

  Future<void> _abrirFicha(int activoId) async {
    if (!_veActivos) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActivoDetalleScreen(activoId: activoId)));
    if (mounted) _cargar();
  }

  Widget _codigoActivo(Mantenimiento m) {
    final texto = Text(m.activoCodigo, style: estiloMono.copyWith(color: _veActivos ? const Color(0xFF1769E0) : null));
    if (!_veActivos) return texto;
    return InkWell(onTap: () => _abrirFicha(m.activoId), child: texto);
  }

  Widget _filaAlerta(Mantenimiento m, bool vencido) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Insignia(
            texto: vencido ? 'Vencido' : 'Próximo',
            fondo: vencido ? Colors.red.shade100 : Colors.amber.shade100,
            colorLetra: vencido ? Colors.red.shade900 : Colors.amber.shade900,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [_codigoActivo(m), const SizedBox(width: 6), Expanded(child: Text(m.activoNombre, overflow: TextOverflow.ellipsis))]),
                Text('${etiqueta(m.tipo)} · ${formatoFecha(m.fechaProgramada)} (${m.textoDias})', style: estiloMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Mantenimiento m) {
    final descripcion = m.descripcion;
    final costo = m.costo;
    final tecnico = m.tecnico;
    final periodicidad = m.periodicidadDias;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _codigoActivo(m)),
              insigniaDe(m.tipo),
              const SizedBox(width: 6),
              insigniaDe(m.estado),
            ],
          ),
          const SizedBox(height: 3),
          Text(m.activoNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Programado: ${formatoFecha(m.fechaProgramada)}${m.estado == 'PROGRAMADO' && m.textoDias.isNotEmpty ? ' (${m.textoDias})' : ''}'
            '${periodicidad != null ? ' · cada $periodicidad días' : ''}',
            style: estiloMuted,
          ),
          if (m.fechaRealizada != null) Text('Realizado: ${formatoFecha(m.fechaRealizada)}', style: estiloMuted),
          if ((tecnico != null && tecnico.isNotEmpty) || costo != null)
            Text('Técnico: ${tecnico ?? '-'} · Costo: ${costo == null ? '-' : formatoBs(costo)}', style: estiloMuted),
          if (descripcion != null && descripcion.isNotEmpty) Text(descripcion, style: estiloMuted),
          if (_puedeEditar && (m.estado == 'PROGRAMADO' || m.estado == 'EN_EJECUCION'))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                children: [
                  if (m.estado == 'PROGRAMADO') TextButton(onPressed: () => _iniciar(m), child: const Text('Iniciar')),
                  if (m.estado == 'EN_EJECUCION') TextButton(onPressed: () => _finalizar(m), child: const Text('Finalizar')),
                  if (m.estado == 'PROGRAMADO') TextButton(onPressed: () => _reprogramar(m), child: const Text('Reprogramar')),
                  TextButton(
                    onPressed: () => _cancelar(m),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Scaffold(
      appBar: barraModulo('Mantenimientos', '/mantenimientos', acciones: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
      ]),
      drawer: const MenuLateral(rutaActual: '/mantenimientos'),
      floatingActionButton: _puedeCrear
          ? FloatingActionButton.extended(
              onPressed: () => _nuevo(),
              icon: const Icon(Icons.add),
              label: const Text('Programar'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            const Subtitulo('Programa preventivos, registra correctivos y controla su costo.'),
            if (_error != null) BannerMensaje(_error!),
            if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
            GrillaKpi(
              items: [
                TarjetaKpi(etiquetaKpi: 'Vencidos sin ejecutar', valor: '${_alertas.vencidos.length}', tono: TonoKpi.mal),
                TarjetaKpi(etiquetaKpi: 'Vencen en 7 días', valor: '${_alertas.proximos.length}', tono: TonoKpi.alerta),
              ],
            ),
            if (_alertas.vencidos.isNotEmpty || _alertas.proximos.isNotEmpty)
              TarjetaSeccion(
                titulo: 'Alertas de mantenimiento',
                hijos: [
                  for (final m in _alertas.vencidos) _filaAlerta(m, true),
                  for (final m in _alertas.proximos) _filaAlerta(m, false),
                ],
              ),
            TarjetaSeccion(
              hijos: [
                TextField(
                  controller: _filtroCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Filtrar por código o nombre del activo',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filtroCtrl.text.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _filtroCtrl.clear())),
                  ),
                ),
                const SizedBox(height: 10),
                CampoSeleccion<String>(
                  etiquetaCampo: 'Estado',
                  valor: _filtroEstado,
                  textoLimpiar: 'Todos los estados',
                  opciones: [
                    for (final e in const ['PROGRAMADO', 'EN_EJECUCION', 'FINALIZADO', 'CANCELADO']) OpcionSeleccion<String>(e, etiqueta(e)),
                  ],
                  onChanged: (v) => setState(() => _filtroEstado = v),
                ),
              ],
            ),
            if (_cargando)
              const Cargando()
            else if (filtrados.isEmpty)
              const MensajeVacio('No hay mantenimientos para mostrar.')
            else
              for (final m in filtrados) _tarjeta(m),
          ],
        ),
      ),
    );
  }
}

// ======================================================================================
// Programar / reprogramar
// ======================================================================================

class _FormMantenimiento extends StatefulWidget {
  final List<Activo> activos;
  final Mantenimiento? editando;
  final int? activoIdInicial;

  const _FormMantenimiento({required this.activos, this.editando, this.activoIdInicial});

  @override
  State<_FormMantenimiento> createState() => _FormMantenimientoState();
}

class _FormMantenimientoState extends State<_FormMantenimiento> {
  final MantenimientoService _service = MantenimientoService();
  final TextEditingController _periodicidadCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();

  int? _activoId;
  String _tipo = 'PREVENTIVO';
  String? _fecha;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final m = widget.editando;
    if (m != null) {
      _activoId = m.activoId;
      _tipo = m.tipo;
      _fecha = m.fechaProgramada;
      _periodicidadCtrl.text = m.periodicidadDias == null ? '' : m.periodicidadDias.toString();
      _descripcionCtrl.text = m.descripcion ?? '';
    } else {
      _activoId = widget.activoIdInicial;
      _fecha = hoyIso();
    }
  }

  @override
  void dispose() {
    _periodicidadCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  List<OpcionSeleccion<int>> _opcionesActivo() {
    final opciones = <OpcionSeleccion<int>>[
      for (final a in widget.activos) OpcionSeleccion<int>(a.id, '${a.codigo} — ${a.nombre} (${a.estadoEtiqueta})'),
    ];
    final m = widget.editando;
    if (m != null && !opciones.any((o) => o.valor == m.activoId)) {
      opciones.add(OpcionSeleccion<int>(m.activoId, '${m.activoCodigo} — ${m.activoNombre}'));
    }
    return opciones;
  }

  Future<void> _guardar() async {
    final activoId = _activoId;
    final fecha = _fecha;
    final descripcion = _descripcionCtrl.text.trim();
    final preventivo = _tipo == 'PREVENTIVO';
    if (activoId == null) {
      setState(() => _error = 'Selecciona el activo.');
      return;
    }
    if (preventivo && (fecha == null || fecha.isEmpty)) {
      setState(() => _error = 'Indica la fecha programada del mantenimiento preventivo.');
      return;
    }
    if (!preventivo && descripcion.isEmpty) {
      setState(() => _error = 'Describe la falla del mantenimiento correctivo.');
      return;
    }
    int? periodicidad;
    if (preventivo && _periodicidadCtrl.text.trim().isNotEmpty) {
      periodicidad = int.tryParse(_periodicidadCtrl.text.trim());
      if (periodicidad == null || periodicidad < 1) {
        setState(() => _error = 'La periodicidad debe ser de al menos 1 día.');
        return;
      }
    }
    setState(() {
      _error = null;
      _guardando = true;
    });
    final fechaEnvio = (fecha == null || fecha.isEmpty) ? null : fecha;
    final descripcionEnvio = descripcion.isEmpty ? null : descripcion;
    try {
      final editando = widget.editando;
      if (editando == null) {
        await _service.programar(
          activoId: activoId,
          tipo: _tipo,
          descripcion: descripcionEnvio,
          fechaProgramada: fechaEnvio,
          periodicidadDias: periodicidad,
        );
      } else {
        await _service.actualizar(
          editando.id,
          activoId: activoId,
          tipo: _tipo,
          descripcion: descripcionEnvio,
          fechaProgramada: fechaEnvio,
          periodicidadDias: periodicidad,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(err, 'No se pudo guardar el mantenimiento.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando != null;
    final preventivo = _tipo == 'PREVENTIVO';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('MANTENIMIENTO', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          Text(
            editando ? 'Reprogramar mantenimiento' : 'Programar mantenimiento',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto),
          ),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          CampoSeleccion<int>(
            etiquetaCampo: 'Activo *',
            valor: _activoId,
            habilitado: !editando,
            opciones: _opcionesActivo(),
            onChanged: (v) => setState(() => _activoId = v),
          ),
          const SizedBox(height: 14),
          const Text('Tipo *', style: estiloMuted),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Preventivo'),
                selected: preventivo,
                onSelected: (_) => setState(() => _tipo = 'PREVENTIVO'),
              ),
              ChoiceChip(
                label: const Text('Correctivo'),
                selected: !preventivo,
                onSelected: (_) => setState(() => _tipo = 'CORRECTIVO'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CampoFecha(
            etiquetaCampo: 'Fecha programada${preventivo ? ' *' : ''}',
            valor: _fecha,
            permitirLimpiar: !preventivo,
            onChanged: (v) => setState(() => _fecha = v),
          ),
          if (preventivo) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _periodicidadCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: decoracion(
                'Periodicidad (días)',
                sugerencia: 'Opcional',
                ayuda: 'Si se indica, al finalizar se programa el siguiente automáticamente.',
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _descripcionCtrl,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: decoracion(_tipo == 'CORRECTIVO' ? 'Descripción de la falla *' : 'Descripción del trabajo'),
          ),
          const SizedBox(height: 10),
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
// Finalizar
// ======================================================================================

class _FormFinalizar extends StatefulWidget {
  final Mantenimiento mantenimiento;

  const _FormFinalizar({required this.mantenimiento});

  @override
  State<_FormFinalizar> createState() => _FormFinalizarState();
}

class _FormFinalizarState extends State<_FormFinalizar> {
  final MantenimientoService _service = MantenimientoService();
  final TextEditingController _costoCtrl = TextEditingController();
  final TextEditingController _tecnicoCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();

  String? _fecha = hoyIso();
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tecnicoCtrl.text = widget.mantenimiento.tecnico ?? '';
  }

  @override
  void dispose() {
    _costoCtrl.dispose();
    _tecnicoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    final costo = leerNumero(_costoCtrl.text);
    final tecnico = _tecnicoCtrl.text.trim();
    if (costo == null || costo < 0 || tecnico.isEmpty) {
      setState(() => _error = 'Indica el costo (0 o más) y el técnico responsable.');
      return;
    }
    final observaciones = _observacionesCtrl.text.trim();
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      await _service.finalizar(
        widget.mantenimiento.id,
        fechaRealizada: _fecha,
        costo: costo,
        tecnico: tecnico,
        observaciones: observaciones.isEmpty ? null : observaciones,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(err, 'No se pudo finalizar el mantenimiento.');
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
          Text(widget.mantenimiento.activoCodigo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          const Text('Finalizar mantenimiento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          CampoFecha(
            etiquetaCampo: 'Fecha realizada',
            valor: _fecha,
            onChanged: (v) => setState(() => _fecha = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _costoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoracion('Costo (Bs) *'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _tecnicoCtrl,
            maxLength: 150,
            decoration: decoracion('Técnico responsable *'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _observacionesCtrl,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: decoracion('Observaciones'),
          ),
          const Text('El activo regresará a su estado previo (Disponible o En uso).', style: estiloMuted),
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
                  onPressed: _guardando ? null : _finalizar,
                  child: Text(_guardando ? 'Guardando...' : 'Finalizar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
