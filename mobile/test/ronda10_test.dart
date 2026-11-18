// Pruebas de la Ronda 10: la app movil no debe mostrar codigo de la base de
// datos (Map/List en crudo) y el boton "Agregar empresa" debe abrir el
// formulario de registro (no otra pantalla).
import 'package:flutter_test/flutter_test.dart';

import 'package:activos_fijos_app/models/json_util.dart';
import 'package:activos_fijos_app/screens/navegacion.dart';
import 'package:activos_fijos_app/screens/registro_empresa_screen.dart';

void main() {
  group('pantallas del menu', () {
    test('"/registro-empresa" abre el formulario de alta de empresa', () {
      final pantalla = pantallaPara('/registro-empresa');
      expect(pantalla, isA<RegistroEmpresaScreen>());
    });

    test('las demas rutas siguen abriendo su propio modulo', () {
      expect(pantallaPara('/activos'), isNot(isA<RegistroEmpresaScreen>()));
      expect(pantallaPara('/inicio'), isNot(isA<RegistroEmpresaScreen>()));
      expect(pantallaPara('/ruta-inexistente'), isNot(isA<RegistroEmpresaScreen>()));
    });
  });

  group('sin codigo de base de datos en pantalla', () {
    test('valorLegible nunca devuelve un mapa o una lista en crudo', () {
      final objeto = {'id': 1, 'nombre': 'Empresa Demo', 'nit': 100000001};
      final texto = valorLegible(objeto);
      expect(texto.contains('{'), isFalse);
      expect(texto.contains('nit'), isFalse);
      expect(texto, 'Empresa Demo');
    });

    test('valorLegible resume las listas por su cantidad', () {
      expect(valorLegible([1, 2, 3]), '3 registros');
      expect(valorLegible(<dynamic>[]), 'sin registros');
      expect(valorLegible([{'nombre': 'A'}]), 'A');
    });

    test('valorLegible formatea las fechas', () {
      expect(valorLegible('2026-10-28T19:30:40'), '28/10/2026 19:30');
      expect(valorLegible('2026-10-28'), '28/10/2026');
      expect(valorLegible(null), '-');
    });

    test('valorLegible de un mapa sin nombre muestra sus primeros campos', () {
      final texto = valorLegible({'total': 5, 'pagados': 2});
      expect(texto.contains('{'), isFalse);
      expect(texto, 'total: 5 · pagados: 2');
    });
  });
}
