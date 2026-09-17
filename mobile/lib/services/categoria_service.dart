import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/categoria.dart';
import 'auth_service.dart';

class CategoriaService {
  final AuthService _auth = AuthService();

  Future<List<Categoria>> listar() async {
    final token = await _auth.getToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/categorias'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Categoria.fromJson(e)).toList();
    }
    throw Exception('No se pudieron cargar las categorias');
  }
}
