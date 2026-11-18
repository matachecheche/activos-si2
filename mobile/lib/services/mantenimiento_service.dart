import '../models/ficha.dart';
import '../models/json_util.dart';
import 'api_client.dart';

/// HU-08: programacion, ejecucion, cierre y cancelacion de mantenimientos.
class MantenimientoService {
  final ApiClient _api = ApiClient();

  Future<List<Mantenimiento>> listar({int? activoId, String? estado}) async {
    final datos = await _api.get('/mantenimientos', consulta: {'activoId': activoId, 'estado': estado});
    return lista<Mantenimiento>(datos, Mantenimiento.fromJson);
  }

  Future<AlertasMantenimiento> alertas() async {
    final datos = await _api.get('/mantenimientos/alertas');
    return AlertasMantenimiento.fromJson(mapa(datos));
  }

  Future<Mantenimiento> programar({
    required int activoId,
    required String tipo,
    String? descripcion,
    String? fechaProgramada,
    int? periodicidadDias,
  }) async {
    final datos = await _api.post('/mantenimientos', {
      'activoId': activoId,
      'tipo': tipo,
      'descripcion': descripcion,
      'fechaProgramada': fechaProgramada,
      'periodicidadDias': periodicidadDias,
    });
    return Mantenimiento.fromJson(mapa(datos));
  }

  Future<Mantenimiento> actualizar(
    int id, {
    required int activoId,
    required String tipo,
    String? descripcion,
    String? fechaProgramada,
    int? periodicidadDias,
  }) async {
    final datos = await _api.put('/mantenimientos/$id', {
      'activoId': activoId,
      'tipo': tipo,
      'descripcion': descripcion,
      'fechaProgramada': fechaProgramada,
      'periodicidadDias': periodicidadDias,
    });
    return Mantenimiento.fromJson(mapa(datos));
  }

  Future<Mantenimiento> iniciar(int id) async {
    final datos = await _api.post('/mantenimientos/$id/iniciar');
    return Mantenimiento.fromJson(mapa(datos));
  }

  Future<Mantenimiento> finalizar(
    int id, {
    String? fechaRealizada,
    required double costo,
    required String tecnico,
    String? observaciones,
  }) async {
    final datos = await _api.post('/mantenimientos/$id/finalizar', {
      'fechaRealizada': fechaRealizada,
      'costo': costo,
      'tecnico': tecnico,
      'observaciones': observaciones,
    });
    return Mantenimiento.fromJson(mapa(datos));
  }

  Future<Mantenimiento> cancelar(int id, String motivo) async {
    final datos = await _api.post('/mantenimientos/$id/cancelar', {'motivo': motivo});
    return Mantenimiento.fromJson(mapa(datos));
  }
}
