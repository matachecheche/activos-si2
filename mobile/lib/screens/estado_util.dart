import 'package:flutter/material.dart';

/// Etiquetas, colores y formatos compartidos por todas las pantallas (equivale a core/util/formato.ts de la web).

const Map<String, String> _etiquetas = {
  'DISPONIBLE': 'Disponible',
  'EN_USO': 'En uso',
  'EN_MANTENIMIENTO': 'En mantenimiento',
  'INACTIVO': 'Inactivo',
  'DADO_DE_BAJA': 'Dado de baja',
  'PROGRAMADO': 'Programado',
  'EN_EJECUCION': 'En ejecución',
  'FINALIZADO': 'Finalizado',
  'CANCELADO': 'Cancelado',
  'PREVENTIVO': 'Preventivo',
  'CORRECTIVO': 'Correctivo',
  'BORRADOR': 'Borrador',
  'APROBADO': 'Aprobado',
  'CERRADO': 'Cerrado',
  'COMPROMISO': 'Compromiso',
  'EJECUCION': 'Ejecución',
};

/// Estados que un activo puede tener (HU-06).
const List<String> estadosActivo = ['DISPONIBLE', 'EN_USO', 'EN_MANTENIMIENTO', 'INACTIVO', 'DADO_DE_BAJA'];

String etiqueta(String? valor) {
  if (valor == null || valor.isEmpty) return '-';
  return _etiquetas[valor] ?? valor;
}

String etiquetaEstado(String? estado) => etiqueta(estado);

MaterialColor _familiaColor(String? valor) {
  switch (valor) {
    case 'EN_USO':
    case 'APROBADO':
    case 'FINALIZADO':
    case 'EJECUCION':
      return Colors.green;
    case 'EN_MANTENIMIENTO':
    case 'MANTENIMIENTO':
    case 'EN_EJECUCION':
    case 'COMPROMISO':
      return Colors.amber;
    case 'DADO_DE_BAJA':
    case 'BAJA':
      return Colors.red;
    case 'INACTIVO':
    case 'CANCELADO':
    case 'BORRADOR':
      return Colors.grey;
    case 'CERRADO':
      return Colors.blueGrey;
    case 'CORRECTIVO':
      return Colors.orange;
    default:
      return Colors.blue; // DISPONIBLE, PROGRAMADO, PREVENTIVO...
  }
}

/// Fondo del distintivo (badge) segun el estado/tipo.
Color colorEstado(String? valor) => _familiaColor(valor).shade100;

/// Color del texto del distintivo (mas oscuro para que se lea bien).
Color colorTextoEstado(String? valor) => _familiaColor(valor).shade900;

// ---------------- numeros ----------------

/// Monto con separador de miles y 2 decimales (igual que number:'1.2-2' de la web): 1,234.50
String formatoMonto(num valor) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final entera = partes[0];
  final sb = StringBuffer();
  for (var i = 0; i < entera.length; i++) {
    if (i > 0 && (entera.length - i) % 3 == 0) sb.write(',');
    sb.write(entera[i]);
  }
  return '${negativo ? '-' : ''}${sb.toString()}.${partes[1]}';
}

String formatoBs(num valor) => 'Bs ${formatoMonto(valor)}';

/// Porcentaje con hasta 2 decimales sin ceros sobrantes (number:'1.0-2').
String formatoPorcentaje(double valor) {
  var s = valor.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Lee un numero escrito por el usuario (acepta coma decimal). Devuelve null si esta vacio o no es valido.
double? leerNumero(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  return double.tryParse(limpio);
}

// ---------------- fechas ----------------

String _dos(int n) => n.toString().padLeft(2, '0');

/// yyyy-MM-dd
String fechaIso(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

String hoyIso() => fechaIso(DateTime.now());

int gestionActual() => DateTime.now().year;

/// 2026-09-18 (o 2026-09-18T10:30:00) -> 18/09/2026
String formatoFecha(String? iso) {
  if (iso == null || iso.length < 10) return '-';
  final p = iso.substring(0, 10).split('-');
  if (p.length != 3) return iso;
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// 2026-09-18T10:30:15 -> 18/09/2026 10:30
String formatoFechaHora(String? iso) {
  if (iso == null || iso.length < 10) return '-';
  final fecha = formatoFecha(iso);
  if (iso.length >= 16 && iso.contains('T')) return '$fecha ${iso.substring(11, 16)}';
  return fecha;
}

/// Numero para un campo de edicion: 1500.0 -> "1500", 1500.5 -> "1500.5".
String numeroParaEditar(double valor) {
  if (valor == valor.roundToDouble()) return valor.toInt().toString();
  return valor.toString();
}
