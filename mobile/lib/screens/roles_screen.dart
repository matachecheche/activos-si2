import 'package:flutter/material.dart';
import '../models/seguridad.dart';
import '../services/api_client.dart';
import '../services/rol_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// HU-04: roles y catalogo de permisos (solo administrador).
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final RolService _service = RolService();

  List<Rol> _roles = <Rol>[];
  List<Permiso> _permisos = <Permiso>[];
  String? _error;
  String? _ok;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final roles = await _service.listar();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e, 'No se pudieron cargar los roles.');
      });
    }
    try {
      final permisos = await _service.permisos();
      if (!mounted) return;
      setState(() => _permisos = permisos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'No se pudieron cargar los permisos.'));
    }
  }

  void _limpiar() {
    _error = null;
    _ok = null;
  }

  // ---------------- roles ----------------

  Future<void> _formRol([Rol? editando]) async {
    setState(_limpiar);
    final guardado = await abrirHoja<bool>(context, _FormRol(permisos: _permisos, editando: editando));
    if (guardado == true && mounted) {
      setState(() => _ok = 'Rol guardado. Los permisos nuevos se aplican a cada usuario en su siguiente inicio de sesión.');
      _cargar();
    }
  }

  /// CP-02: el backend rechaza desactivar un rol con usuarios activos asignados.
  Future<void> _desactivar(Rol rol) async {
    final seguro = await confirmar(
      context,
      '¿Desactivar el rol ${rol.nombre}?',
      titulo: 'Desactivar rol',
      textoSi: 'Desactivar',
      peligro: true,
    );
    if (!seguro || !mounted) return;
    setState(_limpiar);
    try {
      await _service.desactivar(rol.id);
      if (!mounted) return;
      setState(() => _ok = 'Rol ${rol.nombre} desactivado.');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'No se pudo desactivar el rol.'));
    }
  }

  Future<void> _reactivar(Rol rol) async {
    setState(_limpiar);
    try {
      await _service.actualizar(
        rol.id,
        nombre: rol.nombre,
        descripcion: rol.descripcion,
        permisos: rol.permisos.map((p) => p.id).toList(),
        activo: true,
      );
      if (!mounted) return;
      setState(() => _ok = 'Rol ${rol.nombre} reactivado.');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'No se pudo reactivar el rol.'));
    }
  }

  // ---------------- permisos ----------------

  Future<void> _formPermiso([Permiso? editando]) async {
    setState(_limpiar);
    final guardado = await abrirHoja<bool>(context, _FormPermiso(editando: editando));
    if (guardado == true && mounted) _cargar();
  }

  Future<void> _eliminarPermiso(Permiso p) async {
    final seguro = await confirmar(
      context,
      '¿Eliminar el permiso ${p.modulo} / ${p.accion}?',
      titulo: 'Eliminar permiso',
      textoSi: 'Eliminar',
      peligro: true,
    );
    if (!seguro || !mounted) return;
    setState(_limpiar);
    try {
      await _service.eliminarPermiso(p.id);
      if (!mounted) return;
      _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'No se pudo eliminar el permiso.'));
    }
  }

  // ---------------- interfaz ----------------

  Widget _tarjetaRol(Rol rol) {
    final descripcion = rol.descripcion;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(rol.nombre, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
              Insignia(
                texto: rol.activo ? 'Activo' : 'Inactivo',
                fondo: rol.activo ? Colors.green.shade100 : Colors.grey.shade300,
                colorLetra: rol.activo ? Colors.green.shade900 : Colors.grey.shade800,
              ),
            ],
          ),
          if (descripcion != null && descripcion.isNotEmpty) Text(descripcion, style: estiloMuted),
          const SizedBox(height: 4),
          Text('Usuarios activos: ${rol.usuariosActivos} · ${rol.permisos.length} permisos asignados', style: estiloMuted),
          Wrap(
            spacing: 4,
            children: [
              TextButton(onPressed: () => _formRol(rol), child: Text(rol.esAdministrador ? 'Ver' : 'Editar permisos')),
              if (!rol.esAdministrador && rol.activo)
                TextButton(
                  onPressed: () => _desactivar(rol),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  child: const Text('Desactivar'),
                ),
              if (!rol.activo) TextButton(onPressed: () => _reactivar(rol), child: const Text('Reactivar')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filaPermiso(Permiso p) {
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
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Insignia(texto: p.modulo, fondo: Colors.indigo.shade50, colorLetra: Colors.indigo.shade900),
                    Text(p.accion, style: estiloMono),
                  ],
                ),
                const SizedBox(height: 3),
                Text(p.descripcion, style: estiloMuted),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _formPermiso(p),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
            onPressed: () => _eliminarPermiso(p),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraModulo('Roles y permisos', '/roles', acciones: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
      ]),
      drawer: const MenuLateral(rutaActual: '/roles'),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Subtitulo('Define el acceso de cada perfil por módulo.'),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _formRol(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo rol'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _formPermiso(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo permiso'),
                  ),
                ],
              ),
            ),
            if (_error != null) BannerMensaje(_error!),
            if (_ok != null) BannerMensaje(_ok!, tipo: TipoBanner.ok),
            if (_cargando)
              const Cargando()
            else if (_roles.isEmpty)
              const MensajeVacio('No hay roles registrados.')
            else
              for (final r in _roles) _tarjetaRol(r),
            const SizedBox(height: 4),
            TarjetaSeccion(
              titulo: 'Catálogo de permisos',
              accion: Text('${_permisos.length} permisos', style: estiloMuted),
              hijos: [
                const Text('Cada permiso combina un módulo, una acción y una descripción clara.', style: estiloMuted),
                const SizedBox(height: 6),
                if (_permisos.isEmpty)
                  const MensajeVacio('No hay permisos registrados.')
                else
                  for (final p in _permisos) _filaPermiso(p),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================================
// Rol (alta, edicion y asignacion de permisos)
// ======================================================================================

class _FormRol extends StatefulWidget {
  final List<Permiso> permisos;
  final Rol? editando;

  const _FormRol({required this.permisos, this.editando});

  @override
  State<_FormRol> createState() => _FormRolState();
}

class _FormRolState extends State<_FormRol> {
  final RolService _service = RolService();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();

  final Set<int> _seleccion = <int>{};
  String? _error;
  bool _guardando = false;

  bool get _esAdmin => widget.editando?.esAdministrador ?? false;

  @override
  void initState() {
    super.initState();
    final r = widget.editando;
    if (r != null) {
      _nombreCtrl.text = r.nombre;
      _descripcionCtrl.text = r.descripcion ?? '';
      _seleccion.addAll(r.permisos.map((p) => p.id));
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  List<String> get _modulos {
    final modulos = <String>[];
    for (final p in widget.permisos) {
      if (!modulos.contains(p.modulo)) modulos.add(p.modulo);
    }
    return modulos;
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre del rol es obligatorio.');
      return;
    }
    final descripcion = _descripcionCtrl.text.trim();
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      final editando = widget.editando;
      if (editando != null) {
        await _service.actualizar(
          editando.id,
          nombre: nombre,
          descripcion: descripcion.isEmpty ? null : descripcion,
          permisos: _seleccion.toList(),
          activo: editando.activo,
        );
      } else {
        await _service.crear(
          nombre: nombre,
          descripcion: descripcion.isEmpty ? null : descripcion,
          permisos: _seleccion.toList(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e, 'No se pudo guardar el rol.');
      });
    }
  }

  Widget _grupo(String modulo) {
    final permisos = widget.permisos.where((p) => p.modulo == modulo).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(modulo, style: const TextStyle(fontWeight: FontWeight.w700, color: colorTexto)),
          ),
          for (final p in permisos)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(p.accion),
              subtitle: Text(p.descripcion, style: estiloMuted),
              value: _esAdmin || _seleccion.contains(p.id),
              onChanged: _esAdmin
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _seleccion.add(p.id);
                        } else {
                          _seleccion.remove(p.id);
                        }
                      }),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('SEGURIDAD', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          Text(editando != null ? 'Editar rol' : 'Nuevo rol', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          TextField(
            controller: _nombreCtrl,
            enabled: !_esAdmin,
            maxLength: 50,
            textCapitalization: TextCapitalization.characters,
            decoration: decoracion('Nombre del rol'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descripcionCtrl,
            enabled: !_esAdmin,
            maxLength: 160,
            decoration: decoracion('Descripción', sugerencia: 'Qué hace este rol'),
          ),
          if (_esAdmin)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('El rol ADMINISTRADOR tiene acceso total y no puede modificarse ni desactivarse.', style: estiloMuted),
            ),
          const SizedBox(height: 6),
          if (widget.permisos.isEmpty) const MensajeVacio('No hay permisos registrados.'),
          for (final m in _modulos) _grupo(m),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                  child: Text(_esAdmin ? 'Cerrar' : 'Cancelar'),
                ),
              ),
              if (!_esAdmin) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(_guardando ? 'Guardando...' : 'Guardar rol'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ======================================================================================
// Permiso (alta y edicion del catalogo)
// ======================================================================================

class _FormPermiso extends StatefulWidget {
  final Permiso? editando;

  const _FormPermiso({this.editando});

  @override
  State<_FormPermiso> createState() => _FormPermisoState();
}

class _FormPermisoState extends State<_FormPermiso> {
  final RolService _service = RolService();
  final TextEditingController _moduloCtrl = TextEditingController();
  final TextEditingController _accionCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.editando;
    if (p != null) {
      _moduloCtrl.text = p.modulo;
      _accionCtrl.text = p.accion;
      _descripcionCtrl.text = p.descripcion;
    }
  }

  @override
  void dispose() {
    _moduloCtrl.dispose();
    _accionCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final modulo = _moduloCtrl.text.trim();
    final accion = _accionCtrl.text.trim();
    final descripcion = _descripcionCtrl.text.trim();
    if (modulo.isEmpty || accion.isEmpty || descripcion.isEmpty) {
      setState(() => _error = 'Completa módulo, acción y descripción.');
      return;
    }
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      final editando = widget.editando;
      if (editando != null) {
        await _service.actualizarPermiso(editando.id, modulo: modulo, accion: accion, descripcion: descripcion);
      } else {
        await _service.crearPermiso(modulo: modulo, accion: accion, descripcion: descripcion);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e, 'No se pudo guardar el permiso.');
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
          const Text('CATÁLOGO', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          Text(widget.editando != null ? 'Editar permiso' : 'Nuevo permiso', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          TextField(
            controller: _moduloCtrl,
            maxLength: 50,
            textCapitalization: TextCapitalization.characters,
            decoration: decoracion('Módulo', sugerencia: 'Ej.: ACTIVOS', ayuda: 'Nombre del área funcional que se protegerá.'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _accionCtrl,
            maxLength: 20,
            textCapitalization: TextCapitalization.characters,
            decoration: decoracion('Acción', sugerencia: 'Ej.: EDITAR', ayuda: 'Acción concreta permitida para ese módulo.'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descripcionCtrl,
            maxLength: 160,
            minLines: 2,
            maxLines: 3,
            decoration: decoracion('Descripción', sugerencia: 'Ej.: Modificar datos de activos'),
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
                  child: Text(_guardando ? 'Guardando...' : 'Guardar permiso'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
