// Utilidades para leer JSON del backend de forma tolerante (BigDecimal/Long/LocalDate llegan como num o texto).

double numero(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? numeroOpc(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int entero(dynamic v, [int porDefecto = 0]) {
  if (v == null) return porDefecto;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? porDefecto;
}

int? enteroOpc(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String texto(dynamic v, [String porDefecto = '']) => v == null ? porDefecto : v.toString();

String? textoOpc(dynamic v) => v?.toString();

List<T> lista<T>(dynamic v, T Function(Map<String, dynamic> json) convertir) {
  if (v is List) {
    return v.map((e) => convertir(Map<String, dynamic>.from(e as Map))).toList();
  }
  return <T>[];
}

Map<String, dynamic> mapa(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}
