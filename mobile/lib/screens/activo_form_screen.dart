import 'package:flutter/material.dart';
import '../models/activo.dart';
import '../models/categoria.dart';
import '../services/activo_service.dart';
import '../services/api_client.dart';
import '../services/categoria_service.dart';
import '../widgets/comunes.dart';
import 'estado_util.dart';

/// HU-02: alta y edicion de un activo. Devuelve el activo guardado al cerrar (Navigator.pop).
class ActivoFormScreen extends StatefulWidget {
  final Activo? activo;
  final List<Categoria> categorias;

  const ActivoFormScreen({super.key, this.activo, required this.categorias});

  @override
  State<ActivoFormScreen> createState() => _ActivoFormScreenState();
}

class _ActivoFormScreenState extends State<ActivoFormScreen> {
  final ActivoService _service = ActivoService();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _valorCtrl = TextEditingController();
  final TextEditingController _proveedorCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();
  final TextEditingController _residualCtrl = TextEditingController();

  List<Categoria> _categorias = <Categoria>[];
  int? _categoriaId;
  String? _fechaAdquisicion;
  String? _fechaInicioDepreciacion;
  String? _error;
  bool _guardando = false;

  bool get _edicion => widget.activo != null;

  @override
  void initState() {
    super.initState();
    _categorias = widget.categorias;
    final a = widget.activo;
    if (a != null) {
      _nombreCtrl.text = a.nombre;
      _valorCtrl.text = numeroParaEditar(a.valor);
      _proveedorCtrl.text = a.proveedor ?? '';
      _observacionesCtrl.text = a.observaciones ?? '';
      _residualCtrl.text = a.valorResidual == null ? '' : numeroParaEditar(a.valorResidual!);
      _categoriaId = a.categoriaId == 0 ? null : a.categoriaId;
      _fechaAdquisicion = a.fechaAdquisicion.isEmpty ? null : a.fechaAdquisicion;
      _fechaInicioDepreciacion = a.fechaInicioDepreciacion;
    } else {
      _fechaAdquisicion = hoyIso();
    }
    if (_categorias.isEmpty) _cargarCategorias();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _valorCtrl.dispose();
    _proveedorCtrl.dispose();
    _observacionesCtrl.dispose();
    _residualCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final categorias = await CategoriaService().listar();
      if (!mounted) return;
      setState(() => _categorias = categorias);
    } catch (_) {
      // Si falla, el selector queda vacio y el servidor valida al guardar.
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final valor = leerNumero(_valorCtrl.text);
    final categoriaId = _categoriaId;
    final fecha = _fechaAdquisicion;
    if (nombre.isEmpty || categoriaId == null || fecha == null || valor == null) {
      setState(() => _error = 'Completa los campos obligatorios: nombre, categoría, valor y fecha de adquisición.');
      return;
    }
    if (valor <= 0) {
      setState(() => _error = 'El valor de adquisición no puede ser negativo ni cero.');
      return;
    }
    double? residual;
    if (_residualCtrl.text.trim().isNotEmpty) {
      residual = leerNumero(_residualCtrl.text);
      if (residual == null || residual < 0) {
        setState(() => _error = 'El valor residual no puede ser negativo.');
        return;
      }
    }
    final proveedor = _proveedorCtrl.text.trim();
    final observaciones = _observacionesCtrl.text.trim();
    final req = ActivoRequest(
      nombre: nombre,
      categoriaId: categoriaId,
      valor: valor,
      fechaAdquisicion: fecha,
      proveedor: proveedor.isEmpty ? null : proveedor,
      observaciones: observaciones.isEmpty ? null : observaciones,
      valorResidual: residual,
      fechaInicioDepreciacion: _fechaInicioDepreciacion,
    );
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      final actual = widget.activo;
      final resultado = actual == null ? await _service.registrar(req) : await _service.actualizar(actual.id, req);
      if (!mounted) return;
      Navigator.of(context).pop(resultado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e, 'No se pudo guardar el activo.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barra(_edicion ? 'Editar activo' : 'Nuevo activo'),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_edicion) Subtitulo('Código ${widget.activo!.codigo}'),
          if (_error != null) BannerMensaje(_error!),
          TextField(
            controller: _nombreCtrl,
            maxLength: 150,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracion('Nombre *'),
          ),
          const SizedBox(height: 6),
          CampoSeleccion<int>(
            etiquetaCampo: 'Categoría *',
            valor: _categoriaId,
            opciones: [for (final c in _categorias) OpcionSeleccion<int>(c.id, c.nombre)],
            onChanged: (v) => setState(() => _categoriaId = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoracion('Valor de adquisición (Bs) *'),
          ),
          const SizedBox(height: 14),
          CampoFecha(
            etiquetaCampo: 'Fecha de adquisición *',
            valor: _fechaAdquisicion,
            onChanged: (v) => setState(() => _fechaAdquisicion = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _proveedorCtrl,
            maxLength: 150,
            decoration: decoracion('Proveedor'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _observacionesCtrl,
            maxLength: 255,
            minLines: 2,
            maxLines: 4,
            decoration: decoracion('Observaciones'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _residualCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoracion(
              'Valor residual (Bs)',
              ayuda: 'Opcional. Si lo dejas vacío se usa el porcentaje residual de la categoría.',
            ),
          ),
          const SizedBox(height: 14),
          CampoFecha(
            etiquetaCampo: 'Inicio de depreciación',
            valor: _fechaInicioDepreciacion,
            permitirLimpiar: true,
            ayuda: 'Opcional. Si lo dejas vacío se usa la fecha de adquisición.',
            onChanged: (v) => setState(() => _fechaInicioDepreciacion = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.of(context).pop(),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
