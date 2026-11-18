import '../models/json_util.dart';
import 'api_client.dart';

/// HU-11: plan contratado por la empresa, limites y contratacion con la
/// pasarela de pagos real (Mercado Pago o PayPal).
class SuscripcionService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> miSuscripcion() async => mapa(await _api.get('/suscripcion'));

  Future<Map<String, dynamic>> contratar({
    required int planId,
    required String metodoPago,
    int meses = 1,
  }) async {
    return mapa(await _api.post('/suscripcion/contratar', {
      'planId': planId,
      'metodoPago': metodoPago,
      'meses': meses,
    }));
  }

  /// Estado de la pasarela de pagos real (si esta configurada y en que moneda).
  Future<Map<String, dynamic>> estadoPasarela() async => mapa(await _api.get('/pagos/estado'));

  /// Crea el checkout en la pasarela real y devuelve la URL de pago.
  Future<Map<String, dynamic>> crearCheckout({required int planId, int meses = 1}) async {
    return mapa(await _api.post('/pagos/checkout', {'planId': planId, 'meses': meses}));
  }

  /// Estado de un pago por su referencia.
  Future<Map<String, dynamic>> estadoPago(String referencia) async =>
      mapa(await _api.get('/pagos/$referencia'));
}
