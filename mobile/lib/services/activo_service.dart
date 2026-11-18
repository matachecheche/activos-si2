import 'dart:typed_data';
import '../models/activo.dart';
import '../models/ficha.dart';
import '../models/json_util.dart';
import 'api_client.dart';

class ActivoService {
  final ApiClient _api = ApiClient();

  Future<List<Activo>> listar() async {
    final datos = await _api.get('/activos');
    return lista<Activo>(datos, Activo.fromJson);
  }

  Future<Activo> obtener(int id) async {
    final datos = await _api.get('/activos/$id');
    return Activo.fromJson(mapa(datos));
  }

  /// HU-05: el QR de cada activo contiene su codigo; al ingresarlo se abre la ficha.
  Future<Activo> porCodigo(String codigo) async {
    final datos = await _api.get('/activos/codigo/${Uri.encodeComponent(codigo.trim())}');
    return Activo.fromJson(mapa(datos));
  }

  Future<Activo> registrar(ActivoRequest req) async {
    final datos = await _api.post('/activos', req.toJson());
    return Activo.fromJson(mapa(datos));
  }

  Future<Activo> actualizar(int id, ActivoRequest req) async {
    final datos = await _api.put('/activos/$id', req.toJson());
    return Activo.fromJson(mapa(datos));
  }

  /// HU-06: devuelve el activo con su nuevo estado.
  Future<Activo> cambiarEstado(int id, String estado, String motivo) async {
    final datos = await _api.post('/activos/$id/estado', {'estado': estado, 'motivo': motivo});
    return Activo.fromJson(mapa(datos));
  }

  Future<List<HistorialEstado>> historialEstados(int id) async {
    final datos = await _api.get('/activos/$id/historial-estados');
    return lista<HistorialEstado>(datos, HistorialEstado.fromJson);
  }

  /// HU-05: imagen PNG del codigo QR del activo.
  Future<Uint8List> qr(int id, {int tamano = 480}) {
    return _api.descargar('/activos/$id/qr', consulta: {'tamano': tamano});
  }

  /// HU-05: etiqueta imprimible en PDF.
  Future<Uint8List> etiquetaPdf(int id) {
    return _api.descargar('/activos/$id/etiqueta.pdf');
  }

  /// HU-08: mantenimientos del activo y costo total acumulado.
  Future<MantenimientoActivo> mantenimientos(int id) async {
    final datos = await _api.get('/activos/$id/mantenimientos');
    return MantenimientoActivo.fromJson(mapa(datos));
  }
}
