import '../models/json_util.dart';
import '../models/seguridad.dart';
import 'api_client.dart';

/// HU-04: roles y catalogo de permisos (solo administrador, salvo `disponibles`).
class RolService {
  final ApiClient _api = ApiClient();

  Future<List<Rol>> listar() async {
    final datos = await _api.get('/roles');
    return lista<Rol>(datos, Rol.fromJson);
  }

  /// Roles activos que se pueden asignar a un usuario.
  Future<List<RolOpcion>> disponibles() async {
    final datos = await _api.get('/roles/disponibles');
    return lista<RolOpcion>(datos, RolOpcion.fromJson);
  }

  Future<List<Permiso>> permisos() async {
    final datos = await _api.get('/roles/permisos');
    return lista<Permiso>(datos, Permiso.fromJson);
  }

  Future<Rol> crear({required String nombre, String? descripcion, required List<int> permisos, bool activo = true}) async {
    final datos = await _api.post('/roles', {'nombre': nombre, 'descripcion': descripcion, 'permisos': permisos, 'activo': activo});
    return Rol.fromJson(mapa(datos));
  }

  Future<Rol> actualizar(int id, {required String nombre, String? descripcion, required List<int> permisos, required bool activo}) async {
    final datos = await _api.put('/roles/$id', {'nombre': nombre, 'descripcion': descripcion, 'permisos': permisos, 'activo': activo});
    return Rol.fromJson(mapa(datos));
  }

  /// Desactiva el rol (el backend lo rechaza si tiene usuarios activos asignados).
  Future<void> desactivar(int id) async {
    await _api.delete('/roles/$id');
  }

  Future<Permiso> crearPermiso({required String modulo, required String accion, required String descripcion}) async {
    final datos = await _api.post('/roles/permisos', {'modulo': modulo, 'accion': accion, 'descripcion': descripcion});
    return Permiso.fromJson(mapa(datos));
  }

  Future<Permiso> actualizarPermiso(int id, {required String modulo, required String accion, required String descripcion}) async {
    final datos = await _api.put('/roles/permisos/$id', {'modulo': modulo, 'accion': accion, 'descripcion': descripcion});
    return Permiso.fromJson(mapa(datos));
  }

  Future<void> eliminarPermiso(int id) async {
    await _api.delete('/roles/permisos/$id');
  }
}
