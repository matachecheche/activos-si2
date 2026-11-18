import 'json_util.dart';

/// Categoria de activos con sus parametros de depreciacion (HU-07).
class Categoria {
  final int id;
  final String nombre;
  final int? vidaUtil; // en anios
  final String? metodoDepreciacion;
  final double valorResidualPct;
  final bool depreciable;

  Categoria({
    required this.id,
    required this.nombre,
    this.vidaUtil,
    this.metodoDepreciacion,
    this.valorResidualPct = 0,
    this.depreciable = false,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: entero(json['id']),
      nombre: texto(json['nombre']),
      vidaUtil: enteroOpc(json['vidaUtil']),
      metodoDepreciacion: textoOpc(json['metodoDepreciacion']),
      valorResidualPct: numero(json['valorResidualPct']),
      depreciable: json['depreciable'] == true,
    );
  }
}
