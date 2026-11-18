import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// HU-05: compone la etiqueta PNG igual que la web (QR + codigo en negrita + nombre en hasta 2 lineas).
Future<Uint8List> componerEtiquetaPng(Uint8List qrPng, String codigo, String nombre) async {
  final ui.Image qr = await decodeImageFromList(qrPng);
  final double lado = qr.width.toDouble();
  final double ancho = lado + 80;
  final double alto = lado + 190;
  final ui.PictureRecorder grabadora = ui.PictureRecorder();
  final ui.Canvas lienzo = ui.Canvas(grabadora, Rect.fromLTWH(0, 0, ancho, alto));
  lienzo.drawRect(Rect.fromLTWH(0, 0, ancho, alto), Paint()..color = Colors.white);
  lienzo.drawImage(qr, const Offset(40, 30), Paint()..filterQuality = FilterQuality.none);
  _escribir(lienzo, codigo, ancho / 2, lado + 58, ancho - 60, 34, FontWeight.bold, 1);
  _escribir(lienzo, nombre, ancho / 2, lado + 104, ancho - 60, 22, FontWeight.normal, 2);
  final ui.Picture imagenFinal = grabadora.endRecording();
  final ui.Image resultado = await imagenFinal.toImage(ancho.toInt(), alto.toInt());
  final ByteData? datos = await resultado.toByteData(format: ui.ImageByteFormat.png);
  if (datos == null) throw Exception('No se pudo generar la imagen de la etiqueta.');
  return datos.buffer.asUint8List();
}

void _escribir(
  ui.Canvas lienzo,
  String texto,
  double centroX,
  double y,
  double anchoMaximo,
  double tamano,
  FontWeight peso,
  int maxLineas,
) {
  final TextPainter pintor = TextPainter(
    text: TextSpan(text: texto, style: TextStyle(color: Colors.black, fontSize: tamano, fontWeight: peso)),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: maxLineas,
    ellipsis: '...',
  );
  pintor.layout(maxWidth: anchoMaximo);
  pintor.paint(lienzo, Offset(centroX - pintor.width / 2, y));
}

/// "Descargar PNG": abre la hoja de compartir del sistema para guardar o enviar la etiqueta.
Future<void> compartirEtiquetaPng(Uint8List qrPng, String codigo, String nombre) async {
  final Uint8List png = await componerEtiquetaPng(qrPng, codigo, nombre);
  final String archivo = 'etiqueta-$codigo.png';
  await Share.shareXFiles(
    [XFile.fromData(png, name: archivo, mimeType: 'image/png')],
    fileNameOverrides: [archivo],
    subject: 'Etiqueta $codigo',
  );
}

/// "Descargar PDF": guarda o comparte la etiqueta en PDF.
Future<void> compartirEtiquetaPdf(Uint8List pdf, String codigo) async {
  await Printing.sharePdf(bytes: pdf, filename: 'etiqueta-$codigo.pdf');
}

/// "Imprimir": abre el dialogo de impresion del sistema con la etiqueta PDF.
Future<void> imprimirEtiquetaPdf(Uint8List pdf, String codigo) async {
  await Printing.layoutPdf(name: 'Etiqueta $codigo', onLayout: (formato) async => pdf);
}
