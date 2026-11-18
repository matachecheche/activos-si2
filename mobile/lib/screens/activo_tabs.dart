import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/activo.dart';
import '../models/ficha.dart';
import '../services/activo_service.dart';
import '../services/api_client.dart';
import '../services/asignacion_service.dart';
import '../services/auth_service.dart';
import '../services/depreciacion_service.dart';
import '../services/ubicacion_service.dart';
import '../widgets/comunes.dart';
import '../widgets/etiqueta_util.dart';
import '../widgets/tabla_depreciacion.dart';
import 'estado_util.dart';
import 'mantenimientos_screen.dart';

// Pestanas de la ficha del activo. Cada una carga sus propios datos y muestra sus mensajes.

// ======================================================================================
// HU-03: asignacion
// ======================================================================================

class TabAsignacion extends StatefulWidget {
  final Activo activo;
  final ValueChanged<Activo> onActivoCambiado;

  const TabAsignacion({super.key, required this.activo, required this.onActivoCambiado});

  @override
  State<TabAsignacion> createState() => _TabAsignacionState();
}

class _TabAsignacionState extends State<TabAsignacion> {
  final AsignacionService _asignaciones = AsignacionService();
  final UbicacionService _ubicacionService = UbicacionService();
  final ActivoService _activos = ActivoService();
  final AuthService _auth = AuthService();
  final TextEditingController _nuevaUbicacionCtrl = TextEditingController();

  List<Asignacion> _historial = <Asignacion>[];
  List<Responsable> _responsables = <Responsable>[];
  List<Ubicacion> _ubicaciones = <Ubicacion>[];
  int? _responsableId;
  int? _ubicacionId;
  String? _error;
  String? _ok;
  bool _cargando = true;
  bool _asignando = false;

  bool get _puedeEditar => _auth.hasPermission('ACTIVOS_EDITAR');
  bool get _puedeCrear => _auth.hasPermission('ACTIVOS_CREAR');
  bool get _puedeAsignar => _puedeEditar && (widget.activo.estado == 'DISPONIBLE' || widget.activo.estado == 'EN_USO');

  String get _motivoSinAsignar {
    switch (widget.activo.estado) {
      case 'DADO_DE_BAJA':
        return 'Un activo dado de baja no puede asignarse.';
      case 'EN_MANTENIMIENTO':
        return 'El activo está en mantenimiento; podrá asignarse cuando finalice.';
      case 'INACTIVO':
        return 'El activo está inactivo; reactívalo (Disponible) para poder asignarlo.';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nuevaUbicacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    try {
      final h = await _asignaciones.historial(widget.activo.id);
      if (!mounted) return;
      setState(() => _historial = h);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  Future<void> _cargar() async {
    await _cargarHistorial();
    if (_puedeEditar) {
      try {
        final r = await _asignaciones.responsables();
        if (!mounted) return;
        setState(() => _responsables = r);
      } catch (_) {
        if (!mounted) return;
        setState(() => _responsables = <Responsable>[]);
      }
      try {
        final u = await _ubicacionService.listar();
        if (!mounted) return;
        setState(() => _ubicaciones = u);
      } catch (_) {
        if (!mounted) return;
        setState(() => _ubicaciones = <Ubicacion>[]);
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _crearUbicacion() async {
    final nombre = _nuevaUbicacionCtrl.text.trim();
    if (nombre.isEmpty) return;
    try {
      final u = await _ubicacionService.crear(nombre);
      if (!mounted) return;
      setState(() {
        _ubicaciones = [..._ubicaciones, u];
        _ubicacionId = u.id;
        _nuevaUbicacionCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e));
    }
  }

  Future<void> _asignar() async {
    final responsableId = _responsableId;
    final ubicacionId = _ubicacionId;
    if (responsableId == null || ubicacionId == null) {
      setState(() {
        _ok = null;
        _error = 'Selecciona el responsable y la ubicación.';
      });
      return;
    }
    setState(() {
      _error = null;
      _ok = null;
      _asignando = true;
    });
    try {
      await _asignaciones.asignar(activoId: widget.activo.id, responsableId: responsableId, ubicacionId: ubicacionId);
      final actualizado = await _activos.obtener(widget.activo.id);
      if (!mounted) return;
      setState(() {
        _ok = 'Activo asignado correctamente. El estado pasó a En uso.';
        _responsableId = null;
        _ubicacionId = null;
        _asignando = false;
      });
      widget.onActivoCambiado(actualizado);
      await _cargarHistorial();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _asignando = false;
        _error = mensajeError(e, 'No se pudo asignar el activo.');
      });
    }
  }

  String _etiquetaUbicacion(Ubicacion u) {
    final area = u.areaNombre;
    return (area != null && area.isNotEmpty) ? '${u.nombre} — $area' : u.nombre;
  }

  Widget _filaHistorial(Asignacion h) {
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
                Text(formatoFechaHora(h.fechaAsignacion), style: estiloMuted),
                Text(h.responsable.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(h.ubicacion.nombre),
              ],
            ),
          ),
          Insignia(
            texto: h.activa ? 'Vigente' : 'No vigente',
            fondo: h.activa ? Colors.green.shade100 : Colors.grey.shade200,
            colorLetra: h.activa ? Colors.green.shade900 : Colors.grey.shade800,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activo;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_error != null) BannerMensaje(_error!),
        if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
        TarjetaSeccion(
          titulo: 'Asignación actual',
          hijos: [
            Text('Responsable: ${a.responsable?.nombre ?? 'sin asignar'}'),
            const SizedBox(height: 2),
            Text('Ubicación: ${a.ubicacion?.nombre ?? 'sin asignar'}'),
            if (_puedeAsignar) ...[
              const SizedBox(height: 14),
              CampoSeleccion<int>(
                etiquetaCampo: 'Responsable',
                valor: _responsableId,
                opciones: [for (final r in _responsables) OpcionSeleccion<int>(r.id, '${r.nombre} (${r.rol})')],
                onChanged: (v) => setState(() => _responsableId = v),
              ),
              const SizedBox(height: 10),
              CampoSeleccion<int>(
                etiquetaCampo: 'Ubicación',
                valor: _ubicacionId,
                opciones: [for (final u in _ubicaciones) OpcionSeleccion<int>(u.id, _etiquetaUbicacion(u))],
                onChanged: (v) => setState(() => _ubicacionId = v),
              ),
              if (_puedeCrear) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nuevaUbicacionCtrl,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: '¿Falta la ubicación? Nueva ubicación',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _crearUbicacion, child: const Text('Agregar')),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _asignando ? null : _asignar,
                child: Text(_asignando ? 'Asignando...' : (a.responsable != null ? 'Reasignar activo' : 'Asignar activo')),
              ),
              const SizedBox(height: 6),
              const Text(
                'Al asignar, el estado pasa a «En uso» y la asignación anterior queda en el historial.',
                style: estiloMuted,
              ),
            ],
            if (!_puedeAsignar && _motivoSinAsignar.isNotEmpty) ...[
              const SizedBox(height: 12),
              BannerMensaje(_motivoSinAsignar, tipo: TipoBanner.aviso),
            ],
          ],
        ),
        TarjetaSeccion(
          titulo: 'Historial de asignaciones',
          hijos: [
            if (_cargando)
              const Cargando()
            else if (_historial.isEmpty)
              const MensajeVacio('Sin asignaciones registradas.')
            else
              for (final h in _historial) _filaHistorial(h),
          ],
        ),
      ],
    );
  }
}

// ======================================================================================
// HU-06: estado
// ======================================================================================

class TabEstado extends StatefulWidget {
  final Activo activo;
  final ValueChanged<Activo> onActivoCambiado;

  const TabEstado({super.key, required this.activo, required this.onActivoCambiado});

  @override
  State<TabEstado> createState() => _TabEstadoState();
}

class _TabEstadoState extends State<TabEstado> {
  final ActivoService _service = ActivoService();
  final AuthService _auth = AuthService();
  final TextEditingController _motivoCtrl = TextEditingController();

  List<HistorialEstado> _historial = <HistorialEstado>[];
  String? _nuevoEstado;
  String? _error;
  String? _ok;
  bool _cargando = true;
  bool _cambiando = false;

  bool get _puedeEditar => _auth.hasPermission('ACTIVOS_EDITAR');
  bool get _puedeBaja => _auth.hasPermission('ACTIVOS_ELIMINAR');

  /// Un activo dado de baja solo lo reactiva un administrador; la baja exige el permiso ACTIVOS_ELIMINAR.
  List<String> get _opciones {
    final a = widget.activo;
    if (a.estado == 'DADO_DE_BAJA' && !_auth.isAdmin) return <String>[];
    return a.estadosPermitidos.where((e) => e != 'DADO_DE_BAJA' || _puedeBaja).toList();
  }

  String get _ayuda {
    switch (widget.activo.estado) {
      case 'DADO_DE_BAJA':
        return 'Solo un administrador puede reactivar un activo dado de baja.';
      case 'EN_MANTENIMIENTO':
        return 'Finaliza o cancela el mantenimiento en ejecución para cambiar el estado (solo se permite dar de baja).';
      case 'EN_USO':
        return 'Para dejar el activo Disponible se libera su asignación actual.';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    try {
      final h = await _service.historialEstados(widget.activo.id);
      if (!mounted) return;
      setState(() {
        _historial = h;
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

  Future<void> _cambiar() async {
    final nuevo = _nuevoEstado;
    final motivo = _motivoCtrl.text.trim();
    if (nuevo == null) {
      setState(() {
        _ok = null;
        _error = 'Selecciona el nuevo estado.';
      });
      return;
    }
    if (motivo.isEmpty) {
      setState(() {
        _ok = null;
        _error = 'Debes indicar el motivo del cambio de estado.';
      });
      return;
    }
    if (nuevo == 'DADO_DE_BAJA') {
      final seguro = await confirmar(
        context,
        '¿Dar de baja este activo? Dejará de depreciarse y se liberará su asignación.',
        titulo: 'Dar de baja',
        textoSi: 'Dar de baja',
        peligro: true,
      );
      if (!seguro || !mounted) return;
    }
    setState(() {
      _error = null;
      _ok = null;
      _cambiando = true;
    });
    try {
      final activo = await _service.cambiarEstado(widget.activo.id, nuevo, motivo);
      if (!mounted) return;
      setState(() {
        _ok = 'Estado actualizado a ${activo.estadoEtiqueta}.';
        _nuevoEstado = null;
        _motivoCtrl.clear();
        _cambiando = false;
      });
      widget.onActivoCambiado(activo);
      await _cargarHistorial();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cambiando = false;
        _error = mensajeError(e, 'No se pudo cambiar el estado.');
      });
    }
  }

  Widget _filaHistorial(HistorialEstado h) {
    final anterior = h.estadoAnterior;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: colorBorde))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatoFechaHora(h.fecha), style: estiloMuted),
          const SizedBox(height: 3),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              if (anterior != null) insigniaDe(anterior, texto: h.estadoAnteriorEtiqueta),
              if (anterior != null) const Text('→'),
              insigniaDe(h.estadoNuevo, texto: h.estadoNuevoEtiqueta),
            ],
          ),
          const SizedBox(height: 3),
          Text(h.motivo),
          Text('Registró: ${h.usuario}', style: estiloMuted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activo;
    final opciones = _opciones;
    final ayuda = _ayuda;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_error != null) BannerMensaje(_error!),
        if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
        TarjetaSeccion(
          titulo: 'Control de estado',
          hijos: [
            Row(
              children: [
                const Text('Estado actual: '),
                insigniaDe(a.estado, texto: a.estadoEtiqueta),
              ],
            ),
            if (ayuda.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ayuda, style: estiloMuted),
            ],
            if (_puedeEditar && opciones.isNotEmpty) ...[
              const SizedBox(height: 14),
              CampoSeleccion<String>(
                etiquetaCampo: 'Nuevo estado',
                valor: _nuevoEstado,
                opciones: [for (final e in opciones) OpcionSeleccion<String>(e, etiqueta(e))],
                onChanged: (v) => setState(() => _nuevoEstado = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _motivoCtrl,
                maxLength: 255,
                decoration: decoracion('Motivo *', sugerencia: 'Obligatorio para registrar el cambio'),
              ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: _cambiando ? null : _cambiar,
                child: Text(_cambiando ? 'Cambiando...' : 'Cambiar estado'),
              ),
            ],
            if (_puedeEditar && opciones.isEmpty) ...[
              const SizedBox(height: 12),
              const BannerMensaje('No hay cambios manuales disponibles para este estado.', tipo: TipoBanner.aviso),
            ],
          ],
        ),
        TarjetaSeccion(
          titulo: 'Historial de estados',
          hijos: [
            if (_cargando)
              const Cargando()
            else if (_historial.isEmpty)
              const MensajeVacio('El activo no registra cambios de estado.')
            else
              for (final h in _historial) _filaHistorial(h),
          ],
        ),
      ],
    );
  }
}

// ======================================================================================
// HU-05: etiqueta QR
// ======================================================================================

class TabQr extends StatefulWidget {
  final Activo activo;

  const TabQr({super.key, required this.activo});

  @override
  State<TabQr> createState() => _TabQrState();
}

class _TabQrState extends State<TabQr> {
  final ActivoService _service = ActivoService();

  Uint8List? _qr;
  bool _cargando = true;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarQr();
  }

  Future<void> _cargarQr() async {
    try {
      final bytes = await _service.qr(widget.activo.id, tamano: 480);
      if (!mounted) return;
      setState(() {
        _qr = bytes;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudo generar el código QR.');
      });
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion, String errorPorDefecto) async {
    setState(() {
      _error = null;
      _ocupado = true;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e, errorPorDefecto));
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _descargarPng() async {
    final qr = _qr;
    if (qr == null) return;
    await _ejecutar(
      () => compartirEtiquetaPng(qr, widget.activo.codigo, widget.activo.nombre),
      'No se pudo compartir la etiqueta PNG en este dispositivo.',
    );
  }

  Future<void> _descargarPdf() async {
    await _ejecutar(() async {
      final pdf = await _service.etiquetaPdf(widget.activo.id);
      await compartirEtiquetaPdf(pdf, widget.activo.codigo);
    }, 'No se pudo generar la etiqueta PDF.');
  }

  Future<void> _imprimir() async {
    await _ejecutar(() async {
      final pdf = await _service.etiquetaPdf(widget.activo.id);
      await imprimirEtiquetaPdf(pdf, widget.activo.codigo);
    }, 'No se pudo abrir la impresión de la etiqueta.');
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activo;
    final qr = _qr;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_error != null) BannerMensaje(_error!),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: colorBorde),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: qr != null
                      ? Image.memory(qr, width: 240, height: 240, fit: BoxFit.contain, filterQuality: FilterQuality.none)
                      : Center(child: _cargando ? const Text('Generando QR...', style: estiloMuted) : const Icon(Icons.qr_code_2, size: 56, color: Color(0xFF8490A3))),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Etiqueta del activo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorTexto)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'El QR codifica el código único '),
                    TextSpan(text: a.codigo, style: estiloMono),
                    const TextSpan(text: '. Al escanearlo o escribirlo en el buscador de activos se abre esta ficha.'),
                  ],
                ),
                style: estiloMuted,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: (qr == null || _ocupado) ? null : _descargarPng,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Descargar PNG'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : _descargarPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Descargar PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : _imprimir,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Imprimir'),
                  ),
                ],
              ),
              if (_ocupado) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================================
// HU-07: depreciacion del activo
// ======================================================================================

class TabDepreciacion extends StatefulWidget {
  final Activo activo;

  const TabDepreciacion({super.key, required this.activo});

  @override
  State<TabDepreciacion> createState() => _TabDepreciacionState();
}

class _TabDepreciacionState extends State<TabDepreciacion> {
  final DepreciacionService _service = DepreciacionService();
  final AuthService _auth = AuthService();

  DepreciacionActivo? _datos;
  String? _error;
  String? _ok;
  bool _cargando = true;
  bool _calculando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final d = await _service.tabla(widget.activo.id);
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

  Future<void> _calcular() async {
    setState(() {
      _error = null;
      _ok = null;
      _calculando = true;
    });
    try {
      final r = await _service.calcularActivo(widget.activo.id);
      if (!mounted) return;
      setState(() {
        _calculando = false;
        _ok = r.periodosGenerados > 0
            ? 'Se generaron ${r.periodosGenerados} periodo(s) pendiente(s).'
            : 'La depreciación ya estaba al día.';
      });
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculando = false;
        _error = mensajeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_error != null) BannerMensaje(_error!),
        if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
        if (_cargando) const Cargando(),
        if (d != null) ...[
          if (!d.resumen.depreciable) BannerMensaje(d.resumen.observacion ?? 'El activo no se deprecia.', tipo: TipoBanner.aviso),
          GrillaKpi(
            items: [
              TarjetaKpi(etiquetaKpi: 'Valor de adquisición', valor: formatoBs(d.resumen.valorAdquisicion)),
              TarjetaKpi(etiquetaKpi: 'Valor residual', valor: formatoBs(d.resumen.valorResidual)),
              if (d.resumen.depreciable)
                TarjetaKpi(
                  etiquetaKpi: 'Vida útil',
                  valor: '${d.resumen.vidaUtilAnios ?? '-'} años (${d.resumen.vidaUtilMeses ?? '-'} meses)',
                ),
              if (d.resumen.depreciable)
                TarjetaKpi(etiquetaKpi: 'Depreciación mensual', valor: formatoBs(d.resumen.depreciacionMensual)),
              TarjetaKpi(etiquetaKpi: 'Depreciación acumulada', valor: formatoBs(d.resumen.depreciacionAcumulada)),
              TarjetaKpi(etiquetaKpi: 'Valor en libros', valor: formatoBs(d.resumen.valorEnLibros), tono: TonoKpi.bien),
            ],
          ),
          if (d.resumen.depreciable)
            TarjetaSeccion(
              titulo: 'Tabla de depreciación (línea recta)',
              hijos: [
                if (_auth.hasPermission('DEPRECIACION_CREAR'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: _calculando ? null : _calcular,
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      label: Text(_calculando ? 'Calculando...' : 'Calcular periodos pendientes'),
                    ),
                  ),
                TablaDepreciacion(d.filas),
              ],
            ),
        ],
      ],
    );
  }
}

// ======================================================================================
// HU-08: mantenimientos del activo
// ======================================================================================

class TabMantenimientos extends StatefulWidget {
  final Activo activo;

  const TabMantenimientos({super.key, required this.activo});

  @override
  State<TabMantenimientos> createState() => _TabMantenimientosState();
}

class _TabMantenimientosState extends State<TabMantenimientos> {
  final ActivoService _service = ActivoService();
  final AuthService _auth = AuthService();

  MantenimientoActivo? _datos;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final d = await _service.mantenimientos(widget.activo.id);
      if (!mounted) return;
      setState(() {
        _datos = d;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e);
      });
    }
  }

  Future<void> _programar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MantenimientosScreen(activoIdInicial: widget.activo.id)),
    );
    if (mounted) _cargar();
  }

  Widget _fila(Mantenimiento m) {
    final descripcion = m.descripcion;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: colorBorde))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [insigniaDe(m.tipo), insigniaDe(m.estado)],
          ),
          const SizedBox(height: 4),
          Text('Programado: ${formatoFecha(m.fechaProgramada)} · Realizado: ${m.fechaRealizada == null ? '-' : formatoFecha(m.fechaRealizada)}'),
          Text('Técnico: ${m.tecnico ?? '-'} · Costo: ${m.costo == null ? '-' : formatoBs(m.costo!)}', style: estiloMuted),
          if (descripcion != null && descripcion.isNotEmpty) Text(descripcion, style: estiloMuted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_error != null) BannerMensaje(_error!),
        if (_cargando) const Cargando(),
        if (d != null) ...[
          GrillaKpi(
            items: [
              TarjetaKpi(etiquetaKpi: 'Mantenimientos', valor: '${d.items.length}'),
              TarjetaKpi(etiquetaKpi: 'Costo total acumulado', valor: formatoBs(d.costoTotal), tono: TonoKpi.alerta),
            ],
          ),
          TarjetaSeccion(
            titulo: 'Historial de mantenimientos',
            hijos: [
              if (_auth.hasPermission('MANTENIMIENTO_CREAR'))
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _programar,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Programar mantenimiento'),
                  ),
                ),
              if (d.items.isEmpty)
                const MensajeVacio('El activo no tiene mantenimientos registrados.')
              else
                for (final m in d.items) _fila(m),
            ],
          ),
        ],
      ],
    );
  }
}
