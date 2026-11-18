import '../models/json_util.dart';
import 'api_client.dart';

/// HU-11: registro publico de empresas y administracion multi-tenant (Super Admin).
class PlataformaService {
  final ApiClient _api = ApiClient();

  // ---------- publico (sin autenticar) ----------

  Future<List<dynamic>> planes() async => (await _api.get('/public/planes')) as List;

  Future<Map<String, dynamic>> registrarEmpresa(Map<String, Object?> cuerpo) async {
    final datos = await _api.post('/public/registro-empresa', cuerpo);
    return mapa(datos);
  }

  // ---------- Super Admin de la plataforma ----------

  Future<List<dynamic>> empresas() async => (await _api.get('/plataforma/empresas')) as List;

  Future<Map<String, dynamic>> metricas() async => mapa(await _api.get('/plataforma/metricas'));

  Future<Map<String, dynamic>> detalleEmpresa(int id) async =>
      mapa(await _api.get('/plataforma/empresas/$id'));

  Future<Map<String, dynamic>> cambiarEstado(int id, String estado) async =>
      mapa(await _api.post('/plataforma/empresas/$id/estado', null, {'estado': estado}));

  /// Ronda 10: completa los datos de ejemplo de una empresa (categorias, areas,
  /// activos, presupuestos, mantenimiento, inventario...). Solo crea lo que
  /// falta: nunca pisa datos reales.
  Future<Map<String, dynamic>> completarDatosEjemplo(int id) async =>
      mapa(await _api.post('/plataforma/empresas/$id/datos-ejemplo', null));

  /// Completa los datos de ejemplo de todas las empresas de la plataforma.
  Future<Map<String, dynamic>> completarDatosEjemploTodas() async =>
      mapa(await _api.post('/plataforma/datos-ejemplo', null));
}
