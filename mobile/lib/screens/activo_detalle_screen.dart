import 'package:flutter/material.dart';
import '../models/activo.dart';
import '../models/categoria.dart';
import '../services/activo_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/categoria_service.dart';
import '../widgets/comunes.dart';
import 'activo_form_screen.dart';
import 'activo_tabs.dart';
import 'estado_util.dart';

enum _Pestana { datos, asignacion, estado, qr, depreciacion, mantenimientos }

/// Ficha del activo (HU-02/03/05/06/07/08): datos, asignacion, estado, etiqueta QR, depreciacion y mantenimientos.
class ActivoDetalleScreen extends StatefulWidget {
  final int activoId;

  const ActivoDetalleScreen({super.key, required this.activoId});

  @override
  State<ActivoDetalleScreen> createState() => _ActivoDetalleScreenState();
}

class _ActivoDetalleScreenState extends State<ActivoDetalleScreen> with SingleTickerProviderStateMixin {
  final ActivoService _service = ActivoService();
  final AuthService _auth = AuthService();

  late final List<_Pestana> _pestanas;
  late final TabController _tabs;
  int _indiceAnterior = 0;

  Activo? _activo;
  String? _error;
  String? _ok;
  bool _cargando = true;

  bool get _puedeEditar => _auth.hasPermission('ACTIVOS_EDITAR');

  @override
  void initState() {
    super.initState();
    _pestanas = <_Pestana>[
      _Pestana.datos,
      _Pestana.asignacion,
      _Pestana.estado,
      _Pestana.qr,
      if (_auth.hasPermission('DEPRECIACION_LEER')) _Pestana.depreciacion,
      if (_auth.hasPermission('MANTENIMIENTO_LEER')) _Pestana.mantenimientos,
    ];
    _tabs = TabController(length: _pestanas.length, vsync: this);
    _tabs.addListener(_alCambiarPestana);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.removeListener(_alCambiarPestana);
    _tabs.dispose();
    super.dispose();
  }

  void _alCambiarPestana() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index != _indiceAnterior) {
      _indiceAnterior = _tabs.index;
      if (_ok != null || _error != null) {
        setState(() {
          _ok = null;
          _error = null;
        });
      }
    }
  }

  String _nombrePestana(_Pestana p) {
    switch (p) {
      case _Pestana.datos:
        return 'Datos';
      case _Pestana.asignacion:
        return 'Asignación';
      case _Pestana.estado:
        return 'Estado';
      case _Pestana.qr:
        return 'Etiqueta QR';
      case _Pestana.depreciacion:
        return 'Depreciación';
      case _Pestana.mantenimientos:
        return 'Mantenimientos';
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final activo = await _service.obtener(widget.activoId);
      if (!mounted) return;
      setState(() {
        _activo = activo;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudo cargar el activo.');
      });
    }
  }

  void _alCambiarActivo(Activo nuevo) {
    setState(() => _activo = nuevo);
  }

  Future<void> _editar(Activo activo) async {
    var categorias = <Categoria>[];
    try {
      categorias = await CategoriaService().listar();
    } catch (_) {
      // Sin categorias el formulario las vuelve a pedir.
    }
    if (!mounted) return;
    final guardado = await Navigator.of(context).push<Activo>(
      MaterialPageRoute(builder: (_) => ActivoFormScreen(activo: activo, categorias: categorias)),
    );
    if (guardado != null && mounted) {
      setState(() => _ok = 'Activo ${guardado.codigo} actualizado.');
      await _cargar();
    }
  }

  Widget _cabecera(Activo a) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colorTexto)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(a.categoriaNombre, style: estiloMuted),
                    insigniaDe(a.estado, texto: a.estadoEtiqueta),
                  ],
                ),
              ],
            ),
          ),
          if (_puedeEditar && a.editable == true)
            OutlinedButton.icon(
              onPressed: () => _editar(a),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
        ],
      ),
    );
  }

  Widget _contenido(_Pestana p, Activo a) {
    switch (p) {
      case _Pestana.datos:
        return _TabDatos(activo: a);
      case _Pestana.asignacion:
        return TabAsignacion(activo: a, onActivoCambiado: _alCambiarActivo);
      case _Pestana.estado:
        return TabEstado(activo: a, onActivoCambiado: _alCambiarActivo);
      case _Pestana.qr:
        return TabQr(activo: a);
      case _Pestana.depreciacion:
        return TabDepreciacion(activo: a);
      case _Pestana.mantenimientos:
        return TabMantenimientos(activo: a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _activo;
    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Cargando();
    } else if (a == null) {
      cuerpo = ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_error != null) BannerMensaje(_error!),
          OutlinedButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
        ],
      );
    } else {
      cuerpo = Column(
        children: [
          _cabecera(a),
          if (_error != null || _ok != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  if (_error != null) BannerMensaje(_error!),
                  if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [for (final p in _pestanas) _contenido(p, a)],
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: barra(
        a?.codigo ?? 'Ficha del activo',
        abajo: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [for (final p in _pestanas) Tab(text: _nombrePestana(p))],
        ),
      ),
      body: cuerpo,
    );
  }
}

class _TabDatos extends StatelessWidget {
  final Activo activo;

  const _TabDatos({required this.activo});

  @override
  Widget build(BuildContext context) {
    final a = activo;
    final residual = a.valorResidual;
    final baja = a.fechaBaja;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TarjetaSeccion(
          hijos: [
            FilaDato('Código', a.codigo, widgetValor: Text(a.codigo, style: estiloMono)),
            FilaDato('Categoría', a.categoriaNombre),
            FilaDato('Valor de adquisición', formatoBs(a.valor)),
            FilaDato('Valor residual', residual != null ? formatoBs(residual) : '-'),
            FilaDato('Fecha de adquisición', formatoFecha(a.fechaAdquisicion)),
            FilaDato(
              'Inicio de depreciación',
              a.fechaInicioDepreciacion != null && a.fechaInicioDepreciacion!.isNotEmpty ? formatoFecha(a.fechaInicioDepreciacion) : '-',
            ),
            FilaDato('Proveedor', a.proveedor),
            FilaDato('Estado', a.estadoEtiqueta, widgetValor: Align(alignment: Alignment.centerLeft, child: insigniaDe(a.estado, texto: a.estadoEtiqueta))),
            FilaDato('Responsable actual', a.responsable?.nombre),
            FilaDato('Ubicación actual', a.ubicacion?.nombre),
            if (baja != null && baja.isNotEmpty) FilaDato('Fecha de baja', formatoFecha(baja)),
            FilaDato('Observaciones', a.observaciones),
            if (a.editable == false)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Este activo ya tiene movimientos asociados (asignaciones, estados, mantenimientos o ejecuciones), por eso sus datos no pueden editarse.',
                  style: estiloMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
