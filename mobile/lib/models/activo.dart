import 'json_util.dart';

class UsuarioRef {
  final int id;
  final String nombre;
  final String? correo;

  UsuarioRef({required this.id, required this.nombre, this.correo});

  factory UsuarioRef.fromJson(Map<String, dynamic> json) {
    return UsuarioRef(id: entero(json['id']), nombre: texto(json['nombre']), correo: textoOpc(json['correo']));
  }
}

class UbicacionRef {
  final int id;
  final String nombre;

  UbicacionRef({required this.id, required this.nombre});

  factory UbicacionRef.fromJson(Map<String, dynamic> json) {
    return UbicacionRef(id: entero(json['id']), nombre: texto(json['nombre']));
  }
}

/// Ubicacion fisica (opcionalmente dentro de un area) para asignar activos (HU-03).
class Ubicacion {
  final int id;
  final String nombre;
  final int? areaId;
  final String? areaNombre;

  Ubicacion({required this.id, required this.nombre, this.areaId, this.areaNombre});

  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      id: entero(json['id']),
      nombre: texto(json['nombre']),
      areaId: enteroOpc(json['areaId']),
      areaNombre: textoOpc(json['areaNombre']),
    );
  }
}

/// Activo tal como lo devuelve el backend (la categoria llega plana y tambien anidada).
class Activo {
  final int id;
  final String codigo;
  final String nombre;
  final int categoriaId;
  final String categoriaNombre;
  final double valor;
  final double? valorResidual;
  final String fechaAdquisicion; // yyyy-MM-dd
  final String? fechaInicioDepreciacion;
  final String? fechaBaja;
  final String? proveedor;
  final String? observaciones;
  final String estado;
  final String estadoEtiqueta;
  final UsuarioRef? responsable;
  final UbicacionRef? ubicacion;
  final List<String> estadosPermitidos;
  final bool? editable;

  Activo({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.categoriaId,
    required this.categoriaNombre,
    required this.valor,
    this.valorResidual,
    required this.fechaAdquisicion,
    this.fechaInicioDepreciacion,
    this.fechaBaja,
    this.proveedor,
    this.observaciones,
    required this.estado,
    required this.estadoEtiqueta,
    this.responsable,
    this.ubicacion,
    this.estadosPermitidos = const <String>[],
    this.editable,
  });

  factory Activo.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'];
    final responsable = json['responsable'];
    final ubicacion = json['ubicacion'];
    final permitidos = json['estadosPermitidos'];
    final estado = texto(json['estado'], 'DISPONIBLE');
    return Activo(
      id: entero(json['id']),
      codigo: texto(json['codigo']),
      nombre: texto(json['nombre']),
      categoriaId: json['categoriaId'] != null
          ? entero(json['categoriaId'])
          : (categoria is Map ? entero(categoria['id']) : 0),
      categoriaNombre: json['categoriaNombre'] != null
          ? texto(json['categoriaNombre'])
          : (categoria is Map ? texto(categoria['nombre']) : ''),
      valor: numero(json['valor']),
      valorResidual: numeroOpc(json['valorResidual']),
      fechaAdquisicion: texto(json['fechaAdquisicion']),
      fechaInicioDepreciacion: textoOpc(json['fechaInicioDepreciacion']),
      fechaBaja: textoOpc(json['fechaBaja']),
      proveedor: textoOpc(json['proveedor']),
      observaciones: textoOpc(json['observaciones']),
      estado: estado,
      estadoEtiqueta: texto(json['estadoEtiqueta'], estado),
      responsable: responsable is Map ? UsuarioRef.fromJson(Map<String, dynamic>.from(responsable)) : null,
      ubicacion: ubicacion is Map ? UbicacionRef.fromJson(Map<String, dynamic>.from(ubicacion)) : null,
      estadosPermitidos: permitidos is List ? permitidos.map((e) => e.toString()).toList() : <String>[],
      editable: json['editable'] is bool ? json['editable'] as bool : null,
    );
  }
}

/// Cuerpo de las peticiones para registrar/editar un activo (HU-02).
class ActivoRequest {
  final String nombre;
  final int categoriaId;
  final double valor;
  final String fechaAdquisicion;
  final String? proveedor;
  final String? observaciones;
  final double? valorResidual;
  final String? fechaInicioDepreciacion;

  ActivoRequest({
    required this.nombre,
    required this.categoriaId,
    required this.valor,
    required this.fechaAdquisicion,
    this.proveedor,
    this.observaciones,
    this.valorResidual,
    this.fechaInicioDepreciacion,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'categoriaId': categoriaId,
      'valor': valor,
      'fechaAdquisicion': fechaAdquisicion,
      'proveedor': proveedor,
      'observaciones': observaciones,
      'valorResidual': valorResidual,
      'fechaInicioDepreciacion': fechaInicioDepreciacion,
    };
  }
}

/// HU-06: cada cambio de estado queda registrado con su motivo.
class HistorialEstado {
  final int id;
  final String? estadoAnterior;
  final String? estadoAnteriorEtiqueta;
  final String estadoNuevo;
  final String estadoNuevoEtiqueta;
  final String motivo;
  final String usuario;
  final String fecha;

  HistorialEstado({
    required this.id,
    this.estadoAnterior,
    this.estadoAnteriorEtiqueta,
    required this.estadoNuevo,
    required this.estadoNuevoEtiqueta,
    required this.motivo,
    required this.usuario,
    required this.fecha,
  });

  factory HistorialEstado.fromJson(Map<String, dynamic> json) {
    return HistorialEstado(
      id: entero(json['id']),
      estadoAnterior: textoOpc(json['estadoAnterior']),
      estadoAnteriorEtiqueta: textoOpc(json['estadoAnteriorEtiqueta']),
      estadoNuevo: texto(json['estadoNuevo']),
      estadoNuevoEtiqueta: texto(json['estadoNuevoEtiqueta']),
      motivo: texto(json['motivo']),
      usuario: texto(json['usuario']),
      fecha: texto(json['fecha']),
    );
  }
}

/// HU-03: historial de asignaciones (responsable + ubicacion).
class Asignacion {
  final int id;
  final int activoId;
  final String activoCodigo;
  final UsuarioRef responsable;
  final UbicacionRef ubicacion;
  final String fechaAsignacion;
  final bool activa;

  Asignacion({
    required this.id,
    required this.activoId,
    required this.activoCodigo,
    required this.responsable,
    required this.ubicacion,
    required this.fechaAsignacion,
    required this.activa,
  });

  factory Asignacion.fromJson(Map<String, dynamic> json) {
    return Asignacion(
      id: entero(json['id']),
      activoId: entero(json['activoId']),
      activoCodigo: texto(json['activoCodigo']),
      responsable: UsuarioRef.fromJson(mapa(json['responsable'])),
      ubicacion: UbicacionRef.fromJson(mapa(json['ubicacion'])),
      fechaAsignacion: texto(json['fechaAsignacion']),
      activa: json['activa'] == true,
    );
  }
}

/// Usuario que puede ser responsable de un activo.
class Responsable {
  final int id;
  final String nombre;
  final String correo;
  final String rol;

  Responsable({required this.id, required this.nombre, required this.correo, required this.rol});

  factory Responsable.fromJson(Map<String, dynamic> json) {
    return Responsable(
      id: entero(json['id']),
      nombre: texto(json['nombre']),
      correo: texto(json['correo']),
      rol: texto(json['rol']),
    );
  }
}
