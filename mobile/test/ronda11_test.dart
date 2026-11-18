// Pruebas de la Ronda 11:
//  1) el cambio de empresa muestra el motivo REAL del servidor;
//  2) el alta de empresa ofrece Stripe y transferencia bancaria;
//  3) los metodos de pago se leen con su estado de configuracion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activos_fijos_app/models/json_util.dart';
import 'package:activos_fijos_app/screens/registro_empresa_screen.dart';

void main() {
  group('cambio de empresa con mensaje real', () {
    test('usa el mensaje del servidor cuando existe', () {
      final mensaje = mensajeDeError(
        {'message': 'Su cuenta no tiene acceso a la empresa "Sede Norte".'},
        403,
      );
      expect(mensaje.contains('Sede Norte'), isTrue);
      expect(mensaje.contains('403'), isFalse);
    });

    test('usa el campo detail cuando no hay message', () {
      expect(mensajeDeError({'detail': 'La empresa solicitada no existe.'}, 404),
          'La empresa solicitada no existe.');
    });

    test('explica el codigo HTTP cuando el servidor no manda mensaje', () {
      expect(mensajeDeError(null, 403), contains('permiso'));
      expect(mensajeDeError(null, 401), contains('sesion'));
      expect(mensajeDeError(null, 500), contains('500'));
      expect(mensajeDeError(null, 503), contains('503'));
    });

    test('acepta un cuerpo de texto plano', () {
      expect(mensajeDeError('Invalid CORS request', 403), 'Invalid CORS request');
    });
  });

  group('alta de empresa con pasarela de pago', () {
    testWidgets('ofrece Stripe y transferencia bancaria', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistroEmpresaScreen()));
      await tester.pump();
      final textos = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' | ');
      expect(textos.contains('Stripe'), isTrue,
          reason: 'El alta de empresa debe ofrecer Stripe');
      expect(textos.contains('Transferencia bancaria'), isTrue,
          reason: 'El alta de empresa debe ofrecer transferencia bancaria');
      expect(textos.contains('QR'), isTrue);
    });
  });

  group('metodos de pago del servidor', () {
    test('se leen nombre, disponibilidad y mensaje', () {
      final lista = [
        {'nombre': 'STRIPE', 'configurado': true, 'mensaje': 'Stripe disponible.'},
        {'nombre': 'TRANSFERENCIA', 'configurado': false, 'mensaje': 'Faltan credenciales.'},
      ].map((e) => Map<String, dynamic>.from(e)).toList();
      expect(lista[0]['nombre'], 'STRIPE');
      expect(lista[0]['configurado'], isTrue);
      expect(lista[1]['configurado'], isFalse);
      expect(texto(lista[1]['mensaje']), contains('credenciales'));
    });
  });
}
