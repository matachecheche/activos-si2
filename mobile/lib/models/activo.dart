class Activo {
  final int? id;
  final String? codigo;
  final String nombre;
  final int categoriaId;
  final double valor;
  final String fechaAdquisicion; // yyyy-MM-dd
  final String? proveedor;
  final String? observaciones;
  final String? estado;

  Activo({
    this.id,
    this.codigo,
    required this.nombre,
    required this.categoriaId,
    required this.valor,
    required this.fechaAdquisicion,
    this.proveedor,
    this.observaciones,
    this.estado,
  });

  factory Activo.fromJson(Map<String, dynamic> json) {
    return Activo(
      id: json['id'],
      codigo: json['codigo'],
      nombre: json['nombre'],
      categoriaId: json['categoria'] != null ? json['categoria']['id'] : 0,
      valor: (json['valor'] as num).toDouble(),
      fechaAdquisicion: json['fechaAdquisicion'] ?? '',
      proveedor: json['proveedor'],
      observaciones: json['observaciones'],
      estado: json['estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'categoriaId': categoriaId,
      'valor': valor,
      'fechaAdquisicion': fechaAdquisicion,
      'proveedor': proveedor,
      'observaciones': observaciones,
    };
  }
}
