import 'dart:typed_data';
import '../models/json_util.dart';
import 'api_client.dart';

/// HU-16: tablero BI, constructor de consultas, consultas guardadas y
/// exportacion PDF/Excel. La movil cubre las mismas operaciones que la web.
class ReporteService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> bi() async => mapa(await _api.get('/reportes/bi'));

  /// Catalogo de tablas y columnas permitidas (whitelist del backend).
  Future<List<dynamic>> catalogo() async => (await _api.get('/ia/catalogo')) as List;

  /// Ejecuta una especificacion construida a mano.
  Future<Map<String, dynamic>> consultar(Map<String, Object?> espec) async =>
      mapa(await _api.post('/reportes/consultar', espec));

  Future<List<dynamic>> consultasGuardadas() async =>
      (await _api.get('/consultas-guardadas')) as List;

  Future<Map<String, dynamic>> ejecutarGuardada(int id) async =>
      mapa(await _api.get('/consultas-guardadas/$id/ejecutar'));

  Future<Map<String, dynamic>> guardarConsulta({
    required String nombre,
    String entidad = '',
    required String definicion,
  }) async {
    return mapa(await _api.post('/consultas-guardadas', {
      'nombre': nombre,
      'entidad': entidad,
      'definicion': definicion,
    }));
  }

  Future<void> eliminarGuardada(int id) => _api.delete('/consultas-guardadas/$id');

  Future<Uint8List> exportarPdf(Map<String, Object?> espec) =>
      _api.descargarPost('/reportes/exportar/pdf', espec);

  Future<Uint8List> exportarExcel(Map<String, Object?> espec) =>
      _api.descargarPost('/reportes/exportar/excel', espec);
}
