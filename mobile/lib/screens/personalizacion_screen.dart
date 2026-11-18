import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/configuracion_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// HU-13: colores de marca, idioma (es/en), posicion del menu y logo (1 MB).
class PersonalizacionScreen extends StatefulWidget {
  const PersonalizacionScreen({super.key});

  @override
  State<PersonalizacionScreen> createState() => _PersonalizacionScreenState();
}

class _PersonalizacionScreenState extends State<PersonalizacionScreen> {
  final ConfiguracionService _servicio = ConfiguracionService();
  final ImagePicker _picker = ImagePicker();
  final _colorPrimario = TextEditingController();
  final _colorSecundario = TextEditingController();

  Map<String, dynamic> _vista = {};
  Uint8List? _logo;
  String _idioma = 'es';
  String _posicion = 'LATERAL';
  bool _cargando = true;
  bool _ocupado = false;
  String? _aviso;

  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _colorPrimario.dispose();
    _colorSecundario.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final vista = await _servicio.ver();
      final logo = await _servicio.logo();
      if (!mounted) return;
      final menu = ConfiguracionService.menuConfig(vista);
      setState(() {
        _vista = vista;
        _logo = logo;
        _colorPrimario.text = vista['colorPrimario']?.toString() ?? '#1769E0';
        _colorSecundario.text = vista['colorSecundario']?.toString() ?? '#172033';
        _idioma = vista['idioma']?.toString() == 'en' ? 'en' : 'es';
        _posicion = menu.isNotEmpty && menu.first is Map && menu.first['posicion'] == 'SUPERIOR'
            ? 'SUPERIOR'
            : 'LATERAL';
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

  Future<void> _guardar() async {
    if (!_hex.hasMatch(_colorPrimario.text) || !_hex.hasMatch(_colorSecundario.text)) {
      setState(() => _aviso = 'Los colores deben usar el formato #RRGGBB.');
      return;
    }
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      await _servicio.guardar({
        'colorPrimario': _colorPrimario.text,
        'colorSecundario': _colorSecundario.text,
        'idioma': _idioma,
        'menuConfig': '[{"posicion":"$_posicion"}]',
      });
      if (mounted) _snack('Personalización guardada.');
    } catch (e) {
      if (mounted) setState(() => _aviso = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _elegirLogo() async {
    final elegido = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (elegido == null) return;
    final archivo = File(elegido.path);
    if (await archivo.length() > 1024 * 1024) {
      if (mounted) _snack('El logo supera 1 MB. Elige una imagen más pequeña.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final vista = await _servicio.subirLogo(archivo);
      final logo = await _servicio.logo();
      if (!mounted) return;
      setState(() {
        _vista = vista;
        _logo = logo;
        _ocupado = false;
      });
      _snack('Logo actualizado.');
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        _snack('$e');
      }
    }
  }

  void _snack(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  Color? _color(String hex) => _hex.hasMatch(hex) ? Color(int.parse('FF${hex.substring(1)}', radix: 16)) : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/configuracion'),
      appBar: barraModulo('Personalización', '/configuracion'),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: decoracionTarjeta(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorBorde),
                          borderRadius: BorderRadius.circular(10),
                          image: _logo != null
                              ? DecorationImage(image: MemoryImage(_logo!), fit: BoxFit.contain)
                              : null,
                        ),
                        child: _logo == null ? const Icon(Icons.image_not_supported_outlined) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Subir logo (máx. 1 MB)'),
                            onPressed: _ocupado ? null : _elegirLogo,
                          ),
                          if (_vista['tieneLogo'] == true)
                            TextButton(
                              onPressed: () async {
                                await _servicio.borrarLogo();
                                setState(() => _logo = null);
                              },
                              child: const Text('Quitar logo'),
                            ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: decoracionTarjeta(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Colores de marca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    _campoColor('Color primario', _colorPrimario),
                    const SizedBox(height: 12),
                    _campoColor('Color secundario', _colorSecundario),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: decoracionTarjeta(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Idioma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'es', label: Text('Español')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {_idioma},
                      onSelectionChanged: (s) => setState(() => _idioma = s.first),
                    ),
                    const SizedBox(height: 16),
                    const Text('Posición del menú', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'LATERAL', label: Text('Lateral')),
                        ButtonSegment(value: 'SUPERIOR', label: Text('Superior')),
                      ],
                      selected: {_posicion},
                      onSelectionChanged: (s) => setState(() => _posicion = s.first),
                    ),
                  ]),
                ),
                if (_aviso != null) ...[
                  const SizedBox(height: 14),
                  Text(_aviso!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_ocupado ? 'Guardando...' : 'Guardar personalización'),
                  onPressed: _ocupado ? null : _guardar,
                ),
              ],
            ),
    );
  }

  Widget _campoColor(String etiqueta, TextEditingController controller) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: controller,
          decoration: decoracion(etiqueta, sugerencia: '#RRGGBB'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 12),
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _color(controller.text) ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorBorde),
        ),
      ),
    ]);
  }
}
