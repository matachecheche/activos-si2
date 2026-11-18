import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/json_util.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// HU-17: verificacion fisica de inventario con GPS, evidencia fotografica
/// y alternativa manual. La foto se sube primero y el backend devuelve su URL.
class InventarioService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> estadisticas() async {
    return mapa(await _api.get('/inventario/estadisticas'));
  }

  Future<List<dynamic>> verificaciones({int pagina = 0, int tamano = 20}) async {
    final datos = await _api.get('/inventario/verificaciones', consulta: {
      'pagina': pagina,
      'tamano': tamano,
    });
    final paginaResp = mapa(datos);
    final contenido = paginaResp['content'];
    return contenido is List ? contenido : const [];
  }

  /// Sube una foto (JPEG/PNG/WebP, max 5 MB en el backend) y devuelve la URL relativa.
  Future<String> subirFoto(File archivo) async {
    final token = AuthService().token;
    final peticion = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/inventario/foto'),
    );
    if (token != null && token.isNotEmpty) {
      peticion.headers['Authorization'] = 'Bearer $token';
    }
    peticion.files.add(await http.MultipartFile.fromPath('foto', archivo.path));
    final enviado = await peticion.send().timeout(const Duration(seconds: 40));
    final cuerpo = await enviado.stream.bytesToString();
    if (enviado.statusCode < 200 || enviado.statusCode >= 300) {
      String mensaje = 'No se pudo subir la foto.';
      try {
        final json = jsonDecode(cuerpo);
        if (json is Map && json['message'] is String) mensaje = json['message'];
      } catch (_) {}
      throw ApiException(mensaje, enviado.statusCode);
    }
    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    return json['fotoUrl'].toString();
  }

  Future<Map<String, dynamic>> verificar({
    required int activoId,
    required String resultado,
    double? latitud,
    double? longitud,
    double? precisionM,
    String? observacion,
    String? fotoUrl,
  }) async {
    final datos = await _api.post('/inventario/verificaciones', {
      'activoId': activoId,
      'resultado': resultado,
      'latitud': latitud,
      'longitud': longitud,
      'precisionM': precisionM,
      'observacion': observacion,
      'fotoUrl': fotoUrl,
    });
    return mapa(datos);
  }
}
