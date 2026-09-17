import 'package:flutter/material.dart';
import '../models/activo.dart';
import '../models/categoria.dart';
import '../services/activo_service.dart';
import '../services/categoria_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ActivosScreen extends StatefulWidget {
  const ActivosScreen({super.key});

  @override
  State<ActivosScreen> createState() => _ActivosScreenState();
}

class _ActivosScreenState extends State<ActivosScreen> {
  final _activoService = ActivoService();
  final _categoriaService = CategoriaService();
  final _authService = AuthService();

  List<Activo> _activos = [];
  List<Categoria> _categorias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final activos = await _activoService.listar();
      final categorias = await _categoriaService.listar();
      setState(() {
        _activos = activos;
        _categorias = categorias;
      });
    } catch (_) {
      // Si falla (por ejemplo token vencido), no rompemos la pantalla
    } finally {
      setState(() => _cargando = false);
    }
  }

  String _nombreCategoria(int id) {
    final match = _categorias.where((c) => c.id == id);
    return match.isEmpty ? '-' : match.first.nombre;
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'EN_USO':
        return Colors.green.shade100;
      case 'MANTENIMIENTO':
        return Colors.amber.shade100;
      case 'BAJA':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  Future<void> _cerrarSesion() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _abrirFormularioNuevoActivo() {
    final nombreCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final proveedorCtrl = TextEditingController();
    final fechaCtrl = TextEditingController();
    int? categoriaSeleccionada = _categorias.isNotEmpty ? _categorias.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nuevo activo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: categoriaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: _categorias
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                      .toList(),
                  onChanged: (v) => categoriaSeleccionada = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(labelText: 'Valor (Bs)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fechaCtrl,
                  decoration: const InputDecoration(labelText: 'Fecha adquisicion (AAAA-MM-DD)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: proveedorCtrl,
                  decoration: const InputDecoration(labelText: 'Proveedor (opcional)'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (nombreCtrl.text.isEmpty ||
                        categoriaSeleccionada == null ||
                        valorCtrl.text.isEmpty ||
                        fechaCtrl.text.isEmpty) {
                      return;
                    }
                    final nuevo = Activo(
                      nombre: nombreCtrl.text,
                      categoriaId: categoriaSeleccionada!,
                      valor: double.tryParse(valorCtrl.text) ?? 0,
                      fechaAdquisicion: fechaCtrl.text,
                      proveedor: proveedorCtrl.text.isEmpty ? null : proveedorCtrl.text,
                    );
                    try {
                      await _activoService.registrar(nuevo);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _cargarDatos();
                    } catch (_) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('No se pudo registrar el activo')),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar activo'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activos fijos'),
        actions: [
          IconButton(onPressed: _cerrarSesion, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioNuevoActivo,
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: _activos.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay activos registrados todavia.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _activos.length,
                      itemBuilder: (context, index) {
                        final a = _activos[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(a.nombre),
                            subtitle: Text(
                              '${a.codigo ?? ''} - ${_nombreCategoria(a.categoriaId)}\nBs ${a.valor.toStringAsFixed(2)}',
                            ),
                            isThreeLine: true,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _colorEstado(a.estado),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(a.estado ?? 'SIN_ASIGNAR', style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
