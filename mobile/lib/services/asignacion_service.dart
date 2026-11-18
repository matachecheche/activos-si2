import '../models/activo.dart';
import '../models/json_util.dart';
import 'api_client.dart';

/// HU-03: asignacion de activos a un responsable y una ubicacion.
class AsignacionService {
  final ApiClient _api = ApiClient();

  Future<Asignacion> asignar({required int activoId, required int responsableId, required int ubicacionId}) async {
    final datos = await _api.post('/asignaciones', {
      'activoId': activoId,
      'responsableId': responsableId,
      'ubicacionId': ubicacionId,
    });
    return Asignacion.fromJson(mapa(datos));
  }

  Future<List<Asignacion>> historial(int activoId) async {
    final datos = await _api.get('/asignaciones/activo/$activoId');
    return lista<Asignacion>(datos, Asignacion.fromJson);
  }

  Future<List<Responsable>> responsables() async {
    final datos = await _api.get('/asignaciones/responsables');
    return lista<Responsable>(datos, Responsable.fromJson);
  }
}
