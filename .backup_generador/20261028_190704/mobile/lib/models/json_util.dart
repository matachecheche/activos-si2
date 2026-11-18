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

/// Convierte cualquier valor del backend en texto legible para la persona.
/// Nunca devuelve un mapa o una lista en crudo (eso es "codigo de base de
/// datos" en pantalla): los objetos se resumen por su nombre o por sus
/// primeros campos, las listas por su cantidad y las fechas por dd/mm/aaaa.
String valorLegible(dynamic v, {int maxCampos = 3}) {
  if (v == null) return '-';
  if (v is Map) {
    final m = Map<String, dynamic>.from(v);
    final nombre = m['nombre'] ?? m['name'] ?? m['razonSocial'] ?? m['titulo'] ?? m['descripcion'];
    if (nombre != null) return '$nombre';
    if (m.isEmpty) return '-';
    return m.entries
        .take(maxCampos)
        .map((e) => '${e.key}: ${valorLegible(e.value, maxCampos: maxCampos)}')
        .join(' · ');
  }
  if (v is List) {
    if (v.isEmpty) return 'sin registros';
    if (v.length == 1) return valorLegible(v.first, maxCampos: maxCampos);
    return '${v.length} registros';
  }
  if (v is bool) return v ? 'Sí' : 'No';
  final s = v.toString();
  final conHora = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})').firstMatch(s);
  if (conHora != null) {
    return '${conHora.group(3)}/${conHora.group(2)}/${conHora.group(1)} '
        '${conHora.group(4)}:${conHora.group(5)}';
  }
  final soloFecha = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (soloFecha != null) {
    return '${soloFecha.group(3)}/${soloFecha.group(2)}/${soloFecha.group(1)}';
  }
  return s;
}
