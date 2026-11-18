import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// Error de la API con el mensaje listo para mostrar (el backend responde {"message": "..."}).
class ApiException implements Exception {
  final String mensaje;
  final int? estado;

  ApiException(this.mensaje, [this.estado]);

  @override
  String toString() => mensaje;
}

/// Mensaje legible de cualquier error capturado.
String mensajeError(Object e, [String porDefecto = 'Ocurrió un error inesperado. Intenta nuevamente.']) {
  if (e is ApiException) return e.mensaje;
  return porDefecto;
}

/// Cliente HTTP comun: agrega el token, decodifica JSON y traduce los errores del backend.
/// Si el servidor responde 401 (sesion vencida o token invalido) se cierra la sesion y se vuelve al login.
class ApiClient {
  ApiClient._();
  static final ApiClient _instancia = ApiClient._();
  factory ApiClient() => _instancia;

  Uri _uri(String ruta, [Map<String, dynamic>? consulta]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$ruta');
    if (consulta == null || consulta.isEmpty) return base;
    final parametros = <String, String>{};
    consulta.forEach((clave, valor) {
      if (valor != null && valor.toString().isNotEmpty) parametros[clave] = valor.toString();
    });
    if (parametros.isEmpty) return base;
    return base.replace(queryParameters: parametros);
  }

  Map<String, String> _cabeceras({bool json = false}) {
    final cabeceras = <String, String>{'Accept': 'application/json'};
    final token = AuthService().token;
    if (token != null && token.isNotEmpty) cabeceras['Authorization'] = 'Bearer $token';
    if (json) cabeceras['Content-Type'] = 'application/json';
    return cabeceras;
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder (${_hostObjetivo()}).');
    } on http.ClientException {
      throw ApiException('Sin conexión a internet o la red bloquea ${_hostObjetivo()}. '
          'Abre ${ApiConfig.baseUrl} en el navegador del teléfono para comprobarlo.');
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor (${_hostObjetivo()}).');
    }
  }

  /// Host al que apunta el APK: permite diagnosticar en el propio teléfono si
  /// la URL incrustada es la de Azure o una dirección local equivocada.
  String _hostObjetivo() {
    try {
      return Uri.parse(ApiConfig.baseUrl).host;
    } catch (_) {
      return ApiConfig.baseUrl;
    }
  }

  dynamic _decodificar(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  void _verificar(http.Response res) {
    final codigo = res.statusCode;
    if (codigo >= 200 && codigo < 300) return;
    if (codigo == 401) {
      AuthService().expirarSesion();
      throw ApiException('Tu sesión expiró. Inicia sesión nuevamente.', codigo);
    }
    String? mensaje;
    final cuerpo = _decodificar(res);
    if (cuerpo is Map) {
      final m = cuerpo['message'] ?? cuerpo['detail'];
      if (m is String && m.trim().isNotEmpty) mensaje = m;
    }
    if (mensaje == null && codigo == 403) mensaje = 'No tienes permiso para realizar esta operación.';
    throw ApiException(mensaje ?? 'Ocurrió un error inesperado. Intenta nuevamente.', codigo);
  }

  Future<dynamic> get(String ruta, {Map<String, dynamic>? consulta}) async {
    final res = await _enviar(() => http.get(_uri(ruta, consulta), headers: _cabeceras()));
    _verificar(res);
    return _decodificar(res);
  }

  Future<dynamic> post(String ruta, [Object? cuerpo, Map<String, dynamic>? consulta]) async {
    final res = await _enviar(
      () => http.post(_uri(ruta, consulta), headers: _cabeceras(json: true), body: jsonEncode(cuerpo ?? <String, dynamic>{})),
    );
    _verificar(res);
    return _decodificar(res);
  }

  Future<dynamic> put(String ruta, Object cuerpo) async {
    final res = await _enviar(() => http.put(_uri(ruta), headers: _cabeceras(json: true), body: jsonEncode(cuerpo)));
    _verificar(res);
    return _decodificar(res);
  }

  Future<dynamic> delete(String ruta) async {
    final res = await _enviar(() => http.delete(_uri(ruta), headers: _cabeceras()));
    _verificar(res);
    return _decodificar(res);
  }

  /// Descarga binaria (imagen del QR, PDF de la etiqueta).
  Future<Uint8List> descargar(String ruta, {Map<String, dynamic>? consulta}) async {
    final res = await _enviar(() => http.get(_uri(ruta, consulta), headers: _cabeceras()));
    _verificar(res);
    return res.bodyBytes;
  }

  /// Descarga binaria por POST (HU-16: exportar reportes a PDF/Excel enviando la consulta).
  Future<Uint8List> descargarPost(String ruta, Object cuerpo) async {
    final res = await _enviar(
      () => http.post(_uri(ruta), headers: _cabeceras(json: true), body: jsonEncode(cuerpo)),
    );
    _verificar(res);
    return res.bodyBytes;
  }
}
