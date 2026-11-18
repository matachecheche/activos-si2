import '../models/json_util.dart';
import 'api_client.dart';

/// HU-13: bitacora inmutable con filtros y verificacion de la cadena de hashes.
class AuditoriaService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> listar({
    String? usuario,
    String? accion,
    String? entidad,
    int pagina = 0,
    int tamano = 20,
  }) async {
    final params = <String, dynamic>{'pagina': pagina, 'tamano': tamano};
    if (usuario != null && usuario.isNotEmpty) params['usuario'] = usuario;
    if (accion != null && accion.isNotEmpty) params['accion'] = accion;
    if (entidad != null && entidad.isNotEmpty) params['entidad'] = entidad;
    return mapa(await _api.get('/auditoria', consulta: params));
  }

  Future<Map<String, dynamic>> verificarIntegridad() async =>
      mapa(await _api.post('/auditoria/verificar'));
}
