// Modelos de usuarios, roles y permisos (HU-01 / HU-04).
import 'json_util.dart';

class Usuario {
  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final bool activo;

  Usuario({required this.id, required this.nombre, required this.correo, required this.rol, required this.activo});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: entero(json['id']),
      nombre: texto(json['nombre']),
      correo: texto(json['correo']),
      rol: texto(json['rol']),
      activo: json['activo'] != false,
    );
  }
}

class Permiso {
  final int id;
  final String modulo;
  final String accion;
  final String descripcion;

  Permiso({required this.id, required this.modulo, required this.accion, required this.descripcion});

  factory Permiso.fromJson(Map<String, dynamic> json) {
    return Permiso(
      id: entero(json['id']),
      modulo: texto(json['modulo']),
      accion: texto(json['accion']),
      descripcion: texto(json['descripcion']),
    );
  }
}

class Rol {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final List<Permiso> permisos;
  final int usuariosActivos;

  Rol({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.permisos,
    required this.usuariosActivos,
  });

  factory Rol.fromJson(Map<String, dynamic> json) {
    return Rol(
      id: entero(json['id']),
      nombre: texto(json['nombre']),
      descripcion: textoOpc(json['descripcion']),
      activo: json['activo'] != false,
      permisos: lista<Permiso>(json['permisos'], Permiso.fromJson),
      usuariosActivos: entero(json['usuariosActivos']),
    );
  }

  bool get esAdministrador => nombre == 'ADMINISTRADOR';
}

/// Rol activo que puede asignarse a un usuario.
class RolOpcion {
  final int id;
  final String nombre;
  final String? descripcion;

  RolOpcion({required this.id, required this.nombre, this.descripcion});

  factory RolOpcion.fromJson(Map<String, dynamic> json) {
    return RolOpcion(id: entero(json['id']), nombre: texto(json['nombre']), descripcion: textoOpc(json['descripcion']));
  }
}
