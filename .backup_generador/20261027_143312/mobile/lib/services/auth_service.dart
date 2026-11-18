import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Sesion del usuario (HU-01 / HU-04). Es un singleton: `AuthService()` siempre devuelve la misma instancia,
/// asi el token y los permisos se leen de memoria (sin esperar a SharedPreferences) en cada pantalla.
class AuthService {
  AuthService._();
  static final AuthService _instancia = AuthService._();
  factory AuthService() => _instancia;

  /// Igual que la web: la sesion se cierra tras 30 minutos sin actividad.
  static const Duration inactividadMaxima = Duration(minutes: 30);

  /// La app lo asigna para volver al login cuando la sesion vence (token expirado, 401 o inactividad).
  static void Function()? alExpirarSesion;

  /// Mensaje informativo que muestra el login despues de una expiracion de sesion.
  static String? avisoLogin;

  String? _token;
  String _nombre = '';
  String _rol = '';
  String _nivel = 'REGULAR';
  List<String> _permisos = <String>[];
  /// Sprint 3 / multiempresa: empresas a las que el usuario tiene acceso.
  List<Map<String, dynamic>> _empresas = <Map<String, dynamic>>[];
  int? _empresaId;
  String _empresaNombre = '';
  Timer? _temporizador;
  DateTime _ultimaActividad = DateTime.now();

  /// Carga la sesion guardada; se llama una vez al iniciar la app.
  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _nombre = prefs.getString('nombre') ?? '';
    _rol = prefs.getString('rol') ?? '';
    _nivel = prefs.getString('nivel') ?? 'REGULAR';
    _permisos = prefs.getStringList('permisos') ?? <String>[];
    _empresaId = prefs.getInt('empresaId');
    _empresaNombre = prefs.getString('empresaNombre') ?? '';
    final empresas = prefs.getStringList('empresas');
    if (empresas != null && empresas.isNotEmpty) {
      _empresas = empresas
          .map((e) => jsonDecode(e))
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (_token != null && !isLoggedIn()) {
      _token = null;
    }
    if (_token != null) registrarActividad();
  }

  /// Devuelve null si el ingreso fue correcto o el mensaje de error del backend.
  Future<String?> login(String correo, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo, 'password': password}),
          )
          .timeout(const Duration(seconds: 12));
      return await _procesarLogin(res);
    } on TimeoutException {
      return 'El servidor tardó demasiado en responder (${_hostObjetivo()}). '
          'Si esta dirección no es la de Azure, reinstala el APK correcto; si lo es, prueba otra red (datos móviles).';
    } on http.ClientException {
      return 'Sin conexión a internet o red que bloquea ${_hostObjetivo()}. '
          'Prueba con datos móviles o abre esa dirección en el navegador del teléfono.';
    } catch (_) {
      return 'No se pudo conectar con el servidor (${_hostObjetivo()}).';
    }
  }

  /// Host que aparece en los mensajes de error para que en el teléfono se vea
  /// de inmediato si el APK apunta a Azure o a una dirección local equivocada.
  String _hostObjetivo() {
    try {
      return Uri.parse(ApiConfig.baseUrl).host;
    } catch (_) {
      return ApiConfig.baseUrl;
    }
  }

  Future<String?> _procesarLogin(http.Response res) async {
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final permisos = data['permisos'];
      _token = data['token'].toString();
      _nombre = (data['nombre'] ?? '').toString();
      _rol = (data['rol'] ?? '').toString();
      _nivel = (data['nivel'] ?? 'REGULAR').toString().toUpperCase();
      _permisos = permisos is List ? permisos.map((e) => e.toString()).toList() : <String>[];
      final empresas = data['empresas'];
      _empresas = empresas is List
          ? empresas.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      _empresaId = data['empresaId'] is num ? (data['empresaId'] as num).toInt() : null;
      _empresaNombre = (data['empresaNombre'] ?? '').toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('nombre', _nombre);
      await prefs.setString('rol', _rol);
      await prefs.setString('nivel', _nivel);
      await prefs.setStringList('permisos', _permisos);
      if (_empresaId == null) {
        await prefs.remove('empresaId');
      } else {
        await prefs.setInt('empresaId', _empresaId!);
      }
      await prefs.setString('empresaNombre', _empresaNombre);
      await prefs.setStringList('empresas',
          _empresas.map((e) => jsonEncode(e)).toList(growable: false));
      avisoLogin = null;
      registrarActividad();
      return null;
    }
    String? mensaje;
    try {
      final cuerpo = jsonDecode(utf8.decode(res.bodyBytes));
      if (cuerpo is Map && cuerpo['message'] is String) mensaje = cuerpo['message'] as String;
    } catch (_) {}
    if (res.statusCode == 423) {
      return mensaje ?? 'Cuenta bloqueada temporalmente. Intenta nuevamente en unos segundos.';
    }
    if (mensaje != null && mensaje.isNotEmpty) return mensaje;
    return 'Credenciales inválidas.';
  }

  // ---------------- estado de la sesion ----------------

  String? get token => _token;
  String get nombre => _nombre.isEmpty ? 'Usuario' : _nombre;
  String get rol => _rol;
  List<String> get permisos => List<String>.unmodifiable(_permisos);

  bool get isAdmin => _rol.toUpperCase() == 'ADMINISTRADOR';
  bool get isSuperAdmin => _nivel == 'SUPER_ADMIN';
  String get nivel => _nivel;

  // ---------------- multiempresa ----------------

  /// Empresas a las que el usuario tiene acceso (con su rol en cada una).
  List<Map<String, dynamic>> get empresas => List<Map<String, dynamic>>.unmodifiable(_empresas);

  /// Id de la empresa con la que esta abierta la sesion.
  int? get empresaId => _empresaId;

  /// Nombre de la empresa actual.
  String get empresaNombre => _empresaNombre;

  /// Cambia de empresa: el backend devuelve un token nuevo con el rol de esa
  /// empresa. Devuelve el mensaje de error o null si salio bien.
  Future<String?> cambiarEmpresa(int empresaId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/cambiar-empresa'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'empresaId': empresaId}),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        return 'El servidor no cambio de empresa (codigo ${res.statusCode}).';
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final token = data['token'];
      if (token is! String || token.isEmpty) return 'La respuesta del servidor no trae token.';
      _token = token;
      _nombre = (data['nombre'] ?? _nombre).toString();
      _rol = (data['rol'] ?? '').toString();
      _nivel = (data['nivel'] ?? 'REGULAR').toString().toUpperCase();
      final permisos = data['permisos'];
      _permisos = permisos is List ? permisos.map((e) => e.toString()).toList() : <String>[];
      final empresas = data['empresas'];
      _empresas = empresas is List
          ? empresas.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      _empresaId = data['empresaId'] is num ? (data['empresaId'] as num).toInt() : empresaId;
      _empresaNombre = (data['empresaNombre'] ?? '').toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('nombre', _nombre);
      await prefs.setString('rol', _rol);
      await prefs.setString('nivel', _nivel);
      await prefs.setStringList('permisos', _permisos);
      if (_empresaId == null) {
        await prefs.remove('empresaId');
      } else {
        await prefs.setInt('empresaId', _empresaId!);
      }
      await prefs.setString('empresaNombre', _empresaNombre);
      await prefs.setStringList('empresas',
          _empresas.map((e) => jsonEncode(e)).toList(growable: false));
      registrarActividad();
      return null;
    } catch (e) {
      return 'No se pudo cambiar de empresa: $e';
    }
  }

  /// Permiso con el formato MODULO_ACCION (por ejemplo ACTIVOS_EDITAR). El administrador tiene todos.
  bool hasPermission(String permiso) => isSuperAdmin || isAdmin || _permisos.contains(permiso);

  /// Hay token y todavia no vencio (se lee el `exp` del JWT, igual que la web).
  bool isLoggedIn() {
    final t = _token;
    if (t == null || t.isEmpty) return false;
    final exp = _expiracion(t);
    if (exp == null || !exp.isAfter(DateTime.now())) {
      logout();
      return false;
    }
    return true;
  }

  DateTime? _expiracion(String token) {
    try {
      final partes = token.split('.');
      if (partes.length < 2) return null;
      final carga = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
      final datos = jsonDecode(carga);
      if (datos is Map && datos['exp'] is num) {
        return DateTime.fromMillisecondsSinceEpoch(((datos['exp'] as num) * 1000).toInt());
      }
    } catch (_) {}
    return null;
  }

  Future<void> logout() async {
    _temporizador?.cancel();
    _temporizador = null;
    _token = null;
    _nombre = '';
    _rol = '';
    _permisos = <String>[];
    _empresas = <Map<String, dynamic>>[];
    _empresaId = null;
    _empresaNombre = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('nombre');
    await prefs.remove('rol');
    await prefs.remove('permisos');
    await prefs.remove('empresas');
    await prefs.remove('empresaId');
    await prefs.remove('empresaNombre');
  }

  /// La sesion ya no sirve (401, token vencido o inactividad): se limpia y se vuelve al login.
  void expirarSesion([String mensaje = 'Tu sesión expiró. Inicia sesión nuevamente.']) {
    if (_token == null) return;
    logout();
    avisoLogin = mensaje;
    final accion = alExpirarSesion;
    if (accion != null) accion();
  }

  // ---------------- inactividad (30 min) ----------------

  /// Se invoca con cada toque de pantalla: reinicia el contador de inactividad.
  void registrarActividad() {
    _ultimaActividad = DateTime.now();
    if (_token == null) return;
    _temporizador?.cancel();
    _temporizador = Timer(inactividadMaxima, () => expirarSesion('Tu sesión se cerró por inactividad.'));
  }

  /// Al volver de segundo plano los temporizadores pueden haberse pausado: se revisa a mano.
  void revisarInactividad() {
    if (_token == null) return;
    if (DateTime.now().difference(_ultimaActividad) >= inactividadMaxima) {
      expirarSesion('Tu sesión se cerró por inactividad.');
    } else if (!isLoggedIn()) {
      avisoLogin = 'Tu sesión expiró. Inicia sesión nuevamente.';
      final accion = alExpirarSesion;
      if (accion != null) accion();
    }
  }
}
