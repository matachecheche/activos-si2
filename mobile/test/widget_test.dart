// Pruebas de las utilidades de formato y de los modelos (no necesitan servidor ni dispositivo).
import 'package:flutter_test/flutter_test.dart';

import 'package:activos_fijos_app/models/activo.dart';
import 'package:activos_fijos_app/models/ficha.dart';
import 'package:activos_fijos_app/screens/estado_util.dart';

void main() {
  group('formato', () {
    test('formatoMonto usa separador de miles y 2 decimales', () {
      expect(formatoMonto(1234.5), '1,234.50');
      expect(formatoMonto(0), '0.00');
      expect(formatoMonto(-1500000), '-1,500,000.00');
      expect(formatoBs(10), 'Bs 10.00');
    });

    test('formatoPorcentaje quita los ceros sobrantes', () {
      expect(formatoPorcentaje(12.5), '12.5');
      expect(formatoPorcentaje(12), '12');
      expect(formatoPorcentaje(100), '100');
      expect(formatoPorcentaje(0), '0');
    });

    test('leerNumero acepta coma decimal y rechaza texto', () {
      expect(leerNumero('12,5'), 12.5);
      expect(leerNumero(' 7 '), 7);
      expect(leerNumero(''), isNull);
      expect(leerNumero('abc'), isNull);
    });

    test('fechas en formato dd/MM/yyyy', () {
      expect(formatoFecha('2026-09-18'), '18/09/2026');
      expect(formatoFechaHora('2026-09-18T10:30:15'), '18/09/2026 10:30');
      expect(formatoFecha(null), '-');
    });

    test('etiquetas y numeros de edicion', () {
      expect(etiqueta('EN_USO'), 'En uso');
      expect(etiqueta(null), '-');
      expect(numeroParaEditar(1500), '1500');
      expect(numeroParaEditar(1500.5), '1500.5');
    });
  });

  group('modelos', () {
    test('Activo.fromJson lee categoria anidada, responsable y editable', () {
      final a = Activo.fromJson({
        'id': 1,
        'codigo': 'ACT-2026-0001',
        'nombre': 'Laptop',
        'categoria': {'id': 2, 'nombre': 'Equipos'},
        'valor': 1500,
        'fechaAdquisicion': '2026-01-10',
        'estado': 'EN_USO',
        'estadoEtiqueta': 'En uso',
        'responsable': {'id': 3, 'nombre': 'Ana'},
        'estadosPermitidos': ['DISPONIBLE'],
        'editable': false,
      });
      expect(a.categoriaId, 2);
      expect(a.categoriaNombre, 'Equipos');
      expect(a.valor, 1500.0);
      expect(a.responsable?.nombre, 'Ana');
      expect(a.estadosPermitidos, ['DISPONIBLE']);
      expect(a.editable, false);
    });

    test('Mantenimiento.textoDias describe el vencimiento', () {
      Mantenimiento con(int dias) => Mantenimiento.fromJson({
            'id': 1,
            'activoId': 1,
            'activoCodigo': 'A',
            'activoNombre': 'N',
            'tipo': 'PREVENTIVO',
            'estado': 'PROGRAMADO',
            'diasParaVencer': dias,
          });
      expect(con(-3).textoDias, 'vencido hace 3 día(s)');
      expect(con(0).textoDias, 'vence hoy');
      expect(con(5).textoDias, 'en 5 día(s)');
    });
  });
}
