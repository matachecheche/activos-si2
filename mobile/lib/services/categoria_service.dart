import '../models/categoria.dart';
import '../models/json_util.dart';
import 'api_client.dart';

class CategoriaService {
  final ApiClient _api = ApiClient();

  Future<List<Categoria>> listar() async {
    final datos = await _api.get('/categorias');
    return lista<Categoria>(datos, Categoria.fromJson);
  }

  /// HU-07: parametros de depreciacion por categoria. El backend recalcula la depreciacion de la categoria.
  Future<Categoria> actualizar(
    int id, {
    required String nombre,
    required bool depreciable,
    int? vidaUtil,
    double? valorResidualPct,
    String? metodoDepreciacion,
  }) async {
    final datos = await _api.put('/categorias/$id', {
      'nombre': nombre,
      'depreciable': depreciable,
      'vidaUtil': vidaUtil,
      'valorResidualPct': valorResidualPct,
      'metodoDepreciacion': metodoDepreciacion,
    });
    return Categoria.fromJson(mapa(datos));
  }
}
