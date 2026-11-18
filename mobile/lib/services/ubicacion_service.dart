import '../models/activo.dart';
import '../models/json_util.dart';
import 'api_client.dart';

class UbicacionService {
  final ApiClient _api = ApiClient();

  Future<List<Ubicacion>> listar() async {
    final datos = await _api.get('/ubicaciones');
    return lista<Ubicacion>(datos, Ubicacion.fromJson);
  }

  Future<Ubicacion> crear(String nombre, {int? areaId}) async {
    final datos = await _api.post('/ubicaciones', {'nombre': nombre, 'areaId': areaId});
    return Ubicacion.fromJson(mapa(datos));
  }
}
