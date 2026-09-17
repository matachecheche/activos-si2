import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/activo.dart';
import 'auth_service.dart';

class ActivoService {
  final AuthService _auth = AuthService();

  Future<List<Activo>> listar() async {
    final token = await _auth.getToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/activos'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Activo.fromJson(e)).toList();
    }
    throw Exception('No se pudieron cargar los activos');
  }

  Future<void> registrar(Activo activo) async {
    final token = await _auth.getToken();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/activos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(activo.toJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('No se pudo registrar el activo');
    }
  }
}
