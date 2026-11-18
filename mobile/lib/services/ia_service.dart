import '../models/json_util.dart';
import 'api_client.dart';

/// HU-14: asistente en lenguaje natural. El backend decide el proveedor
/// (Groq, Gemini o modo GUIADO sin clave) y solo ejecuta SELECT seguros
/// limitados a la empresa del usuario.
class IaService {
  final ApiClient _api = ApiClient();

  /// [historial] son los ultimos turnos (rol usuario/asistente) para que el
  /// modelo entienda preguntas de seguimiento, igual que en la web.
  Future<Map<String, dynamic>> preguntar(String pregunta, {List<Map<String, String>>? historial}) async {
    final cuerpo = <String, dynamic>{'pregunta': pregunta};
    if (historial != null && historial.isNotEmpty) cuerpo['historial'] = historial;
    return mapa(await _api.post('/ia/consulta', cuerpo));
  }

  /// Diagnostico de configuracion (que proveedores tienen clave y su formato).
  Future<Map<String, dynamic>> estado() async => mapa(await _api.get('/ia/estado'));

  /// Prueba en vivo contra Groq y Gemini y devuelve el detalle de cada intento.
  Future<List<dynamic>> probar() async => (await _api.post('/ia/probar')) as List;
}
