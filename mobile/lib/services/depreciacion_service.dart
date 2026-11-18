import '../models/ficha.dart';
import '../models/json_util.dart';
import 'api_client.dart';

/// HU-07: depreciacion por linea recta y valor en libros.
class DepreciacionService {
  final ApiClient _api = ApiClient();

  Future<List<ResumenDepreciacion>> resumen() async {
    final datos = await _api.get('/depreciacion/resumen');
    return lista<ResumenDepreciacion>(datos, ResumenDepreciacion.fromJson);
  }

  Future<DepreciacionActivo> tabla(int activoId) async {
    final datos = await _api.get('/depreciacion/activo/$activoId');
    return DepreciacionActivo.fromJson(mapa(datos));
  }

  /// Calcula los periodos pendientes de todos los activos (idempotente) hasta yyyy-MM; por defecto el actual.
  Future<CalculoDepreciacion> calcular({String? periodo}) async {
    final datos = await _api.post('/depreciacion/calcular', <String, dynamic>{}, {'periodo': periodo});
    return CalculoDepreciacion.fromJson(mapa(datos));
  }

  Future<CalculoDepreciacion> calcularActivo(int activoId, {String? periodo}) async {
    final datos = await _api.post('/depreciacion/activo/$activoId/calcular', <String, dynamic>{}, {'periodo': periodo});
    return CalculoDepreciacion.fromJson(mapa(datos));
  }
}
