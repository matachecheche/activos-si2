import 'package:flutter/material.dart';
import '../models/seguridad.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/rol_service.dart';
import '../services/usuario_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// Administracion de cuentas de usuario: alta, edicion, desactivacion y reactivacion.
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final UsuarioService _service = UsuarioService();
  final RolService _rolService = RolService();
  final AuthService _auth = AuthService();

  List<Usuario> _usuarios = <Usuario>[];
  List<RolOpcion> _roles = <RolOpcion>[];
  bool _cargando = true;
  String? _error;

  bool get _puedeCrear => _auth.hasPermission('USUARIOS_CREAR');
  bool get _puedeEditar => _auth.hasPermission('USUARIOS_EDITAR');
  bool get _puedeEliminar => _auth.hasPermission('USUARIOS_ELIMINAR');

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
    _cargarRoles();
  }

  Future<void> _cargarRoles() async {
    try {
      final roles = await _rolService.disponibles();
      if (!mounted) return;
      setState(() => _roles = roles);
    } catch (_) {
      if (!mounted) return;
      setState(() => _roles = <RolOpcion>[]);
    }
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargando = true);
    try {
      final usuarios = await _service.listar();
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Error al obtener usuarios. Verifique sus permisos de administrador.';
      });
    }
  }

  Future<void> _formulario([Usuario? editando]) async {
    final guardado = await abrirHoja<bool>(context, _FormUsuario(roles: _roles, editando: editando));
    if (guardado == true && mounted) {
      setState(() => _error = null);
      _cargarUsuarios();
    }
  }

  Future<void> _desactivar(Usuario u) async {
    final seguro = await confirmar(
      context,
      '¿Desactivar este usuario? Podrá reactivarse más adelante.',
      titulo: 'Desactivar usuario',
      textoSi: 'Desactivar',
      peligro: true,
    );
    if (!seguro || !mounted) return;
    try {
      await _service.desactivar(u.id);
      if (!mounted) return;
      setState(() => _error = null);
      _cargarUsuarios();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'Error al desactivar usuario'));
    }
  }

  Future<void> _reactivar(Usuario u) async {
    try {
      await _service.actualizar(u.id, nombre: u.nombre, correo: u.correo, rol: u.rol, activo: true);
      if (!mounted) return;
      setState(() => _error = null);
      _cargarUsuarios();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeError(e, 'Error al reactivar usuario'));
    }
  }

  Widget _tarjeta(Usuario u) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(u.nombre, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
              Text('ID ${u.id}', style: estiloMuted),
            ],
          ),
          Text(u.correo, style: estiloMuted),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              Insignia(texto: u.rol, fondo: Colors.indigo.shade50, colorLetra: Colors.indigo.shade900),
              Insignia(
                texto: u.activo ? 'Activo' : 'Inactivo',
                fondo: u.activo ? Colors.green.shade100 : Colors.grey.shade300,
                colorLetra: u.activo ? Colors.green.shade900 : Colors.grey.shade800,
              ),
            ],
          ),
          if (_puedeEditar || (_puedeEliminar && u.activo))
            Wrap(
              spacing: 4,
              children: [
                if (_puedeEditar) TextButton(onPressed: () => _formulario(u), child: const Text('Editar')),
                if (_puedeEliminar && u.activo)
                  TextButton(
                    onPressed: () => _desactivar(u),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    child: const Text('Desactivar'),
                  ),
                if (_puedeEditar && !u.activo) TextButton(onPressed: () => _reactivar(u), child: const Text('Reactivar')),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraModulo('Usuarios', '/usuarios', acciones: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargarUsuarios),
      ]),
      drawer: const MenuLateral(rutaActual: '/usuarios'),
      floatingActionButton: _puedeCrear
          ? FloatingActionButton.extended(
              onPressed: () => _formulario(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo usuario'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _cargarUsuarios,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            const Subtitulo('Gestiona las cuentas y permisos del sistema.'),
            if (_auth.isAdmin)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    onPressed: () => irAModulo(context, '/roles'),
                    icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                    label: const Text('Configurar roles y permisos'),
                  ),
                ),
              ),
            if (_error != null) BannerMensaje(_error!),
            if (_cargando)
              const Cargando()
            else if (_usuarios.isEmpty)
              const MensajeVacio('No hay usuarios para mostrar.')
            else
              for (final u in _usuarios) _tarjeta(u),
          ],
        ),
      ),
    );
  }
}

// ======================================================================================
// Alta / edicion de usuario
// ======================================================================================

class _FormUsuario extends StatefulWidget {
  final List<RolOpcion> roles;
  final Usuario? editando;

  const _FormUsuario({required this.roles, this.editando});

  @override
  State<_FormUsuario> createState() => _FormUsuarioState();
}

class _FormUsuarioState extends State<_FormUsuario> {
  static final RegExp _passwordSegura = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z\d]).{8,}$');

  final UsuarioService _service = UsuarioService();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  String _rol = 'ENCARGADO_ACTIVOS';
  bool _verPassword = false;
  String? _error;
  bool _guardando = false;

  bool get _edicion => widget.editando != null;

  @override
  void initState() {
    super.initState();
    final u = widget.editando;
    if (u != null) {
      _nombreCtrl.text = u.nombre;
      _correoCtrl.text = u.correo;
      _rol = u.rol;
    } else if (widget.roles.isNotEmpty && !widget.roles.any((r) => r.nombre == _rol)) {
      _rol = widget.roles.first.nombre;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  List<OpcionSeleccion<String>> _opcionesRol() {
    final opciones = <OpcionSeleccion<String>>[
      for (final r in widget.roles) OpcionSeleccion<String>(r.nombre, r.nombre),
    ];
    if (!opciones.any((o) => o.valor == _rol)) opciones.add(OpcionSeleccion<String>(_rol, _rol));
    return opciones;
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final correo = _correoCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (nombre.isEmpty || correo.isEmpty) {
      setState(() => _error = 'Completa el nombre y el correo electrónico.');
      return;
    }
    if ((!_edicion || password.isNotEmpty) && !_passwordSegura.hasMatch(password)) {
      setState(() => _error = 'La contraseña debe tener mínimo 8 caracteres, mayúscula, minúscula, número y carácter especial.');
      return;
    }
    setState(() {
      _error = null;
      _guardando = true;
    });
    try {
      final editando = widget.editando;
      if (editando != null) {
        await _service.actualizar(editando.id, nombre: nombre, correo: correo, rol: _rol, activo: editando.activo);
      } else {
        await _service.crear(nombre: nombre, correo: correo, password: password, rol: _rol);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e, _edicion ? 'Error al actualizar usuario' : 'Error al crear usuario');
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
          const Text('CUENTAS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF1769E0))),
          Text(_edicion ? 'Editar usuario' : 'Nuevo usuario', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorTexto)),
          const SizedBox(height: 12),
          if (_error != null) BannerMensaje(_error!),
          TextField(
            controller: _nombreCtrl,
            maxLength: 150,
            textCapitalization: TextCapitalization.words,
            decoration: decoracion('Nombre completo'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _correoCtrl,
            maxLength: 150,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: decoracion('Correo electrónico'),
          ),
          if (!_edicion) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _passwordCtrl,
              obscureText: !_verPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                helperText: '8 caracteres: mayúscula, minúscula, número y símbolo.',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _verPassword = !_verPassword),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          CampoSeleccion<String>(
            etiquetaCampo: 'Rol',
            valor: _rol,
            opciones: _opcionesRol(),
            onChanged: (v) => setState(() => _rol = v ?? _rol),
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
                  child: Text(_guardando ? 'Guardando...' : 'Guardar usuario'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
