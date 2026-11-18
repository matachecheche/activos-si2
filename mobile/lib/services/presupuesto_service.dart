import '../models/json_util.dart';
import '../models/presupuesto.dart';
import 'api_client.dart';

/// HU-09 (presupuestos y partidas) y HU-10 (ejecucion y seguimiento).
class PresupuestoService {
  final ApiClient _api = ApiClient();

  Future<List<Presupuesto>> listar({int? gestion, int? areaId}) async {
    final datos = await _api.get('/presupuestos', consulta: {'gestion': gestion, 'areaId': areaId});
    return lista<Presupuesto>(datos, Presupuesto.fromJson);
  }

  Future<Presupuesto> crear({required int areaId, required int gestion, required double montoAprobado}) async {
    final datos = await _api.post('/presupuestos', {'areaId': areaId, 'gestion': gestion, 'montoAprobado': montoAprobado});
    return Presupuesto.fromJson(mapa(datos));
  }

  Future<Presupuesto> actualizar(int id, {required int areaId, required int gestion, required double montoAprobado}) async {
    final datos = await _api.put('/presupuestos/$id', {'areaId': areaId, 'gestion': gestion, 'montoAprobado': montoAprobado});
    return Presupuesto.fromJson(mapa(datos));
  }

  Future<Presupuesto> aprobar(int id) async {
    final datos = await _api.post('/presupuestos/$id/aprobar');
    return Presupuesto.fromJson(mapa(datos));
  }

  Future<Presupuesto> cerrar(int id) async {
    final datos = await _api.post('/presupuestos/$id/cerrar');
    return Presupuesto.fromJson(mapa(datos));
  }

  Future<void> eliminar(int id) async {
    await _api.delete('/presupuestos/$id');
  }

  Future<Seguimiento> seguimiento(int id) async {
    final datos = await _api.get('/presupuestos/$id/seguimiento');
    return Seguimiento.fromJson(mapa(datos));
  }

  Future<Partida> crearPartida(int presupuestoId, {required String codigo, required String nombre, required double montoPlanificado}) async {
    final datos = await _api.post('/presupuestos/$presupuestoId/partidas', {
      'codigo': codigo,
      'nombre': nombre,
      'montoPlanificado': montoPlanificado,
    });
    return Partida.fromJson(mapa(datos));
  }

  Future<Partida> actualizarPartida(
    int presupuestoId,
    int partidaId, {
    required String codigo,
    required String nombre,
    required double montoPlanificado,
  }) async {
    final datos = await _api.put('/presupuestos/$presupuestoId/partidas/$partidaId', {
      'codigo': codigo,
      'nombre': nombre,
      'montoPlanificado': montoPlanificado,
    });
    return Partida.fromJson(mapa(datos));
  }

  Future<void> eliminarPartida(int presupuestoId, int partidaId) async {
    await _api.delete('/presupuestos/$presupuestoId/partidas/$partidaId');
  }

  Future<List<Ejecucion>> ejecuciones(int presupuestoId) async {
    final datos = await _api.get('/presupuestos/$presupuestoId/ejecuciones');
    return lista<Ejecucion>(datos, Ejecucion.fromJson);
  }

  Future<Ejecucion> registrarEjecucion({
    required int partidaId,
    required String tipo,
    required String fecha,
    required String concepto,
    required double monto,
    int? activoId,
    int? compromisoId,
  }) async {
    final datos = await _api.post('/ejecuciones', {
      'partidaId': partidaId,
      'tipo': tipo,
      'fecha': fecha,
      'concepto': concepto,
      'monto': monto,
      'activoId': activoId,
      'compromisoId': compromisoId,
    });
    return Ejecucion.fromJson(mapa(datos));
  }

  Future<List<Area>> areas() async {
    final datos = await _api.get('/areas');
    return lista<Area>(datos, Area.fromJson);
  }

  Future<Area> crearArea(String nombre, {String? descripcion}) async {
    final datos = await _api.post('/areas', {'nombre': nombre, 'descripcion': descripcion});
    return Area.fromJson(mapa(datos));
  }
}
