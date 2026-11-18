import 'package:flutter/material.dart';
import '../models/json_util.dart';
import '../services/auditoria_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// HU-13: bitacora inmutable. Filtros por usuario/accion/entidad y boton
/// para verificar la cadena de hashes SHA-256 (igual que la web).
class BitacoraScreen extends StatefulWidget {
  const BitacoraScreen({super.key});

  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
  final AuditoriaService _servicio = AuditoriaService();
  final _usuario = TextEditingController();
  final _entidad = TextEditingController();

  List<dynamic> _filas = [];
  bool _cargando = true;
  bool _hayMas = true;
  int _pagina = 0;
  String? _aviso;
  static const int _tamano = 20;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _usuario.dispose();
    _entidad.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _cargando = true;
      _aviso = null;
      _pagina = 0;
      _filas = [];
      _hayMas = true;
    });
    await _cargarPagina();
  }

  Future<void> _cargarPagina() async {
    try {
      final pagina = await _servicio.listar(
        usuario: _usuario.text,
        entidad: _entidad.text,
        pagina: _pagina,
        tamano: _tamano,
      );
      final contenido = (pagina['content'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _filas = [..._filas, ...contenido];
        _hayMas = pagina['last'] != true && contenido.length == _tamano;
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

  Future<void> _verificar() async {
    try {
      final r = await _servicio.verificarIntegridad();
      if (!mounted) return;
      final integra = r['integra'] == true;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(integra ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
              color: integra ? const Color(0xFF166534) : const Color(0xFF991B1B), size: 40),
          title: Text(integra ? 'Bitácora íntegra' : 'Registros alterados'),
          content: Text(
            integra
                ? 'La cadena de hashes SHA-256 es válida: ningún registro fue modificado ni eliminado.'
                : 'Se detectaron ${r['registrosAlterados']} registros alterados. Revisa la seguridad del sistema.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
        ),
      );
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  void _snack(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/auditoria'),
      appBar: barraModulo('Bitácora de auditoría', '/auditoria', acciones: [
        IconButton(tooltip: 'Verificar integridad', icon: const Icon(Icons.verified_outlined), onPressed: _verificar),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _usuario,
                decoration: decoracion('Usuario', sugerencia: 'Nombre o correo'),
                onSubmitted: (_) => _recargar(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _entidad,
                decoration: decoracion('Entidad', sugerencia: 'Ej. activo'),
                onSubmitted: (_) => _recargar(),
              ),
            ),
            IconButton(icon: const Icon(Icons.filter_alt_outlined), onPressed: _recargar),
          ]),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _filas.isEmpty
                  ? Center(child: Text(_aviso ?? 'No hay registros con esos filtros.'))
                  : RefreshIndicator(
                      onRefresh: _recargar,
                      child: ListView.builder(
                        itemCount: _filas.length + (_hayMas ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _filas.length) {
                            _pagina++;
                            _cargarPagina();
                            return const Padding(
                              padding: EdgeInsets.all(14),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _entrada(mapa(_filas[i]));
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _entrada(Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: decoracionTarjeta(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Chip(
            label: Text(texto(m['accion']), style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(texto(m['entidad']), style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(texto(m['fechaHora']), style: estiloMuted),
        ]),
        const SizedBox(height: 4),
        Text('${texto(m['usuarioNombre'])} · ${texto(m['ip'])}', style: estiloMuted),
        if (texto(m['entidadId']).isNotEmpty) Text('ID entidad: ${texto(m['entidadId'])}', style: estiloMuted),
        if (texto(m['detalle']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(texto(m['detalle']), maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }
}
