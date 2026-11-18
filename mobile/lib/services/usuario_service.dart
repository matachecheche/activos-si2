import '../models/json_util.dart';
import '../models/seguridad.dart';
import 'api_client.dart';

/// Administracion de cuentas de usuario.
class UsuarioService {
  final ApiClient _api = ApiClient();

  Future<List<Usuario>> listar() async {
    final datos = await _api.get('/usuarios');
    return lista<Usuario>(datos, Usuario.fromJson);
  }

  Future<Usuario> crear({required String nombre, required String correo, required String password, required String rol}) async {
    final datos = await _api.post('/usuarios', {'nombre': nombre, 'correo': correo, 'password': password, 'rol': rol});
    return Usuario.fromJson(mapa(datos));
  }

  Future<Usuario> actualizar(int id, {required String nombre, required String correo, required String rol, required bool activo}) async {
    final datos = await _api.put('/usuarios/$id', {'nombre': nombre, 'correo': correo, 'rol': rol, 'activo': activo});
    return Usuario.fromJson(mapa(datos));
  }

  /// El backend desactiva la cuenta (se puede reactivar despues).
  Future<void> desactivar(int id) async {
    await _api.delete('/usuarios/$id');
  }
}
