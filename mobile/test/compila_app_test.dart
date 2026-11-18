// Test temporal: comprueba que toda la app compila (importa el punto de entrada).
import 'package:flutter_test/flutter_test.dart';
import 'package:activos_fijos_app/main.dart';

void main() {
  test('la app compila', () {
    expect(ActivosFijosApp, isNotNull);
  });
}
