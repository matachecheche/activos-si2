import 'dart:typed_data';
import '../models/json_util.dart';
import 'api_client.dart';

/// HU-15: respaldos con hash SHA-256, programacion, descarga y restauracion
/// transaccional.
class RespaldoService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> listar() async => (await _api.get('/respaldos')) as List;

  /// Descarga el archivo del respaldo (mismo endpoint que la web).
  Future<Uint8List> descargar(int id) => _api.descargar('/respaldos/$id/descargar');

  Future<Map<String, dynamic>> crear() async => mapa(await _api.post('/respaldos'));

  Future<Map<String, dynamic>> restaurar(int id) async =>
      mapa(await _api.post('/respaldos/$id/restaurar'));

  Future<Map<String, dynamic>> verProgramacion() async =>
      mapa(await _api.get('/respaldos/programacion'));

  Future<Map<String, dynamic>> guardarProgramacion(Map<String, Object?> cuerpo) async =>
      mapa(await _api.put('/respaldos/programacion', cuerpo));
}
