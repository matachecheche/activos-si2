import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/activo.dart';
import '../models/json_util.dart';
import '../services/activo_service.dart';
import '../services/inventario_service.dart';
import '../widgets/comunes.dart';
import 'escaner_qr_screen.dart';
import 'navegacion.dart';

/// HU-17: verificacion fisica de inventario.
/// Integra escaneo QR, GPS y camara, siempre con alternativa manual:
/// si el usuario deniega un permiso (o no hay hardware) puede escribir el
/// codigo, las coordenadas y omitir la foto.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final InventarioService _servicio = InventarioService();
  final ActivoService _activoService = ActivoService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _idManual = TextEditingController();
  final TextEditingController _observacion = TextEditingController();

  Activo? _activo;
  String _resultado = 'ENCONTRADO';
  double? _latitud;
  double? _longitud;
  double? _precision;
  String? _fotoUrl;
  File? _fotoLocal;
  bool _ocupado = false;
  String? _aviso;
  Map<String, dynamic> _stats = {};
  List<dynamic> _recientes = [];
  int _pagina = 0;
  bool _hayMas = false;
  bool _cargandoMas = false;

  static const _resultados = {
    'ENCONTRADO': 'Encontrado',
    'NO_ENCONTRADO': 'No encontrado',
    'DIFERENCIA_ESTADO': 'Diferencia de estado',
  };

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  @override
  void dispose() {
    _idManual.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _cargarResumen() async {
    try {
      final stats = await _servicio.estadisticas();
      final recientes = await _servicio.verificaciones(pagina: 0);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _recientes = recientes;
        _pagina = 0;
        _hayMas = recientes.length >= 20;
      });
    } catch (_) {/* el formulario sigue usable aunque fallen las estadisticas */}
  }

  /// HU-17: la web pagina el historial completo; en el movil se cargan mas
  /// paginas de 20 en 20 con este boton.
  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMas) return;
    setState(() => _cargandoMas = true);
    try {
      final nuevos = await _servicio.verificaciones(pagina: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _recientes = [..._recientes, ...nuevos];
        _pagina = _pagina + 1;
        _hayMas = nuevos.length >= 20;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  // ---------------- QR / identificacion del activo ----------------

  Future<void> _escanearQr() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanerQrScreen()),
    );
    if (codigo == null || codigo.isEmpty) return;
    await _buscarPorCodigo(codigo);
  }

  Future<void> _buscarPorCodigo(String codigo) async {
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      final activo = await _activoService.porCodigo(codigo);
      if (!mounted) return;
      setState(() {
        _activo = activo;
        _idManual.text = activo.id.toString();
        _ocupado = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _aviso = 'No se encontró un activo con ese código: $e';
      });
    }
  }

  Future<void> _buscarPorIdManual() async {
    final texto = _idManual.text.trim();
    final id = int.tryParse(texto);
    if (id == null) {
      setState(() => _aviso = 'Escribe un ID numérico válido.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final activo = await _activoService.obtener(id);
      if (!mounted) return;
      setState(() {
        _activo = activo;
        _ocupado = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _aviso = 'Activo no legible: $e';
      });
    }
  }

  // ---------------- GPS con permiso y alternativa manual ----------------

  Future<void> _capturarGps() async {
    setState(() => _aviso = null);
    bool habilitado = await Geolocator.isLocationServiceEnabled();
    if (!habilitado) {
      setState(() => _aviso = 'El GPS está apagado. Actívalo o ingresa las coordenadas manualmente.');
      return;
    }
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      setState(() => _aviso = 'Permiso de ubicación denegado. Puedes escribir latitud y longitud manualmente.');
      return;
    }
    final posicion = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 15), onTimeout: () {
      throw TimeoutException('No se pudo obtener la ubicación a tiempo.');
    }).catchError((Object e) {
      throw Exception('No se pudo obtener la ubicación. Ingresa las coordenadas manualmente.');
    });
    if (!mounted) return;
    setState(() {
      _latitud = posicion.latitude;
      _longitud = posicion.longitude;
      _precision = posicion.accuracy;
    });
  }

  // ---------------- Foto con camara / galeria ----------------

  Future<void> _tomarFoto(ImageSource origen) async {
    try {
      final elegido = await _picker.pickImage(source: origen, maxWidth: 1920, imageQuality: 80);
      if (elegido == null) return;
      setState(() {
        _ocupado = true;
        _aviso = null;
      });
      final url = await _servicio.subirFoto(File(elegido.path));
      if (!mounted) return;
      setState(() {
        _fotoLocal = File(elegido.path);
        _fotoUrl = url;
        _ocupado = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _aviso = 'No se pudo adjuntar la foto: $e. Puedes continuar sin evidencia.';
      });
    }
  }

  // ---------------- Registro ----------------

  Future<void> _registrar() async {
    final id = int.tryParse(_idManual.text.trim());
    if (id == null) {
      setState(() => _aviso = 'Identifica el activo escaneando el QR o escribiendo su ID.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      await _servicio.verificar(
        activoId: id,
        resultado: _resultado,
        latitud: _latitud,
        longitud: _longitud,
        precisionM: _precision,
        observacion: _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
        fotoUrl: _fotoUrl,
      );
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _activo = null;
        _fotoUrl = null;
        _fotoLocal = null;
        _latitud = null;
        _longitud = null;
        _precision = null;
        _aviso = null;
        _idManual.clear();
        _observacion.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verificación registrada correctamente.')),
      );
      _cargarResumen();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _aviso = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/inventario'),
      appBar: barraModulo('Verificación de inventario', '/inventario'),
      body: RefreshIndicator(
        onRefresh: _cargarResumen,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_stats.isNotEmpty) _tarjetaStats(),
            const SizedBox(height: 14),
            Container(
              decoration: decoracionTarjeta(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('1. Identifica el activo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Escanear QR'),
                      onPressed: _ocupado ? null : _escanearQr,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _idManual,
                      keyboardType: TextInputType.number,
                      decoration: decoracion('ID manual', sugerencia: 'Alternativa sin cámara'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Buscar por ID',
                    icon: const Icon(Icons.search),
                    onPressed: _ocupado ? null : _buscarPorIdManual,
                  ),
                ]),
                if (_activo != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_activo!.codigo} · ${_activo!.nombre}'),
                  ),
                ],
                const SizedBox(height: 18),
                const Text('2. Resultado de la verificación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _resultado,
                  decoration: decoracion('Resultado'),
                  items: _resultados.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _resultado = v ?? 'ENCONTRADO'),
                ),
                const SizedBox(height: 18),
                const Text('3. Ubicación GPS (opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Usar mi GPS'),
                      onPressed: _ocupado ? null : _capturarGps,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _latitud == null
                          ? 'Sin coordenadas'
                          : '${_latitud!.toStringAsFixed(5)}, ${_longitud!.toStringAsFixed(5)}'
                              '${_precision != null ? ' (±${_precision!.toStringAsFixed(0)} m)' : ''}',
                      style: estiloMuted,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _latitud?.toStringAsFixed(6),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: decoracion('Latitud manual'),
                      onChanged: (v) => _latitud = double.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: _longitud?.toStringAsFixed(6),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: decoracion('Longitud manual'),
                      onChanged: (v) => _longitud = double.tryParse(v),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                const Text('4. Evidencia fotográfica (opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cámara'),
                      onPressed: _ocupado ? null : () => _tomarFoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Galería'),
                      onPressed: _ocupado ? null : () => _tomarFoto(ImageSource.gallery),
                    ),
                  ),
                ]),
                if (_fotoLocal != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_fotoLocal!, height: 140, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: _observacion,
                  maxLines: 3,
                  decoration: decoracion('Observación', sugerencia: 'Novedades encontradas durante el conteo'),
                ),
                if (_aviso != null) ...[
                  const SizedBox(height: 12),
                  Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(_ocupado ? 'Enviando...' : 'Registrar verificación'),
                    onPressed: _ocupado ? null : _registrar,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('Verificaciones recientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ..._recientes.map((v) => _filaVerificacion(v)),
            if (_recientes.isEmpty) const Text('Aún no hay verificaciones registradas.', style: estiloMuted),
            if (_hayMas)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: TextButton.icon(
                  onPressed: _cargandoMas ? null : _cargarMas,
                  icon: _cargandoMas
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.expand_more),
                  label: const Text('Cargar más verificaciones'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaStats() {
    return Wrap(spacing: 10, runSpacing: 10, children: _stats.entries.map((e) {
      return Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: decoracionTarjeta(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entero(e.value).toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(e.key, style: estiloMuted),
        ]),
      );
    }).toList());
  }

  Widget _filaVerificacion(dynamic v) {
    final m = mapa(v);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: decoracionTarjeta(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Activo #${texto(m['activoId'])}',
                style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(texto(m['resultado']), style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
        ]),
        const SizedBox(height: 4),
        Text(valorLegible(m['fechaHora']), style: estiloMuted),
        if (m['latitud'] != null)
          Text('GPS: ${texto(m['latitud'])}, ${texto(m['longitud'])}', style: estiloMono),
        if (m['observacion'] != null && texto(m['observacion']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(texto(m['observacion'])),
          ),
      ]),
    );
  }
}
