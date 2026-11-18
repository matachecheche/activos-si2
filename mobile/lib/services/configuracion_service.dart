import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/json_util.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// HU-13: personalizacion de la empresa (colores, idioma, posicion del menu, logo).
class ConfiguracionService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> ver() async => mapa(await _api.get('/configuracion'));

  Future<Map<String, dynamic>> guardar(Map<String, String> cuerpo) async =>
      mapa(await _api.put('/configuracion', cuerpo));

  /// Elimina el logo actual.
  Future<void> borrarLogo() => _api.delete('/configuracion/logo');

  /// Sube un logo (maximo 1 MB en el backend) y devuelve la vista actualizada.
  Future<Map<String, dynamic>> subirLogo(File archivo) async {
    final token = AuthService().token;
    final peticion = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/configuracion/logo'),
    );
    if (token != null && token.isNotEmpty) {
      peticion.headers['Authorization'] = 'Bearer $token';
    }
    peticion.files.add(await http.MultipartFile.fromPath('logo', archivo.path));
    final enviado = await peticion.send().timeout(const Duration(seconds: 40));
    final cuerpo = await enviado.stream.bytesToString();
    if (enviado.statusCode < 200 || enviado.statusCode >= 300) {
      throw ApiException('No se pudo subir el logo (máximo 1 MB).', enviado.statusCode);
    }
    return mapa(jsonDecode(cuerpo));
  }

  /// Devuelve los bytes del logo (o null si la empresa no tiene).
  Future<Uint8List?> logo() async {
    final token = AuthService().token;
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/configuracion/logo'),
      headers: token == null ? {} : {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 204 || res.bodyBytes.isEmpty) return null;
    if (res.statusCode != 200) return null;
    return res.bodyBytes;
  }

  /// Decodifica el menuConfig (JSON serializado) de forma tolerante.
  static List<dynamic> menuConfig(Map<String, dynamic> vista) {
    final crudo = vista['menuConfig'];
    if (crudo is List) return crudo;
    if (crudo is String && crudo.isNotEmpty) {
      try {
        final decodificado = jsonDecode(crudo);
        return decodificado is List ? decodificado : const [];
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }
}
