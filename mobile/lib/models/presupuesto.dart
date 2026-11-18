// Modelos de HU-09 / HU-10: presupuestos, partidas, seguimiento y ejecucion presupuestaria.
import 'json_util.dart';

class Area {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  Area({required this.id, required this.nombre, this.descripcion, required this.activo});

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: entero(json['id']),
      nombre: texto(json['nombre']),
      descripcion: textoOpc(json['descripcion']),
      activo: json['activo'] != false,
    );
  }
}

class Presupuesto {
  final int id;
  final int areaId;
  final String areaNombre;
  final int gestion;
  final double montoAprobado;
  final String estado; // BORRADOR | APROBADO | CERRADO
  final String? fechaAprobacion;
  final String? aprobador;
  final double montoPlanificado;
  final double sinDistribuir;
  final double comprometido;
  final double ejecutado;
  final double saldoDisponible;
  final double porcentajeEjecucion;

  Presupuesto({
    required this.id,
    required this.areaId,
    required this.areaNombre,
    required this.gestion,
    required this.montoAprobado,
    required this.estado,
    this.fechaAprobacion,
    this.aprobador,
    required this.montoPlanificado,
    required this.sinDistribuir,
    required this.comprometido,
    required this.ejecutado,
    required this.saldoDisponible,
    required this.porcentajeEjecucion,
  });

  factory Presupuesto.fromJson(Map<String, dynamic> json) {
    return Presupuesto(
      id: entero(json['id']),
      areaId: entero(json['areaId']),
      areaNombre: texto(json['areaNombre']),
      gestion: entero(json['gestion']),
      montoAprobado: numero(json['montoAprobado']),
      estado: texto(json['estado']),
      fechaAprobacion: textoOpc(json['fechaAprobacion']),
      aprobador: textoOpc(json['aprobador']),
      montoPlanificado: numero(json['montoPlanificado']),
      sinDistribuir: numero(json['sinDistribuir']),
      comprometido: numero(json['comprometido']),
      ejecutado: numero(json['ejecutado']),
      saldoDisponible: numero(json['saldoDisponible']),
      porcentajeEjecucion: numero(json['porcentajeEjecucion']),
    );
  }
}

class Partida {
  final int id;
  final int presupuestoId;
  final String codigo;
  final String nombre;
  final double montoPlanificado;
  final double comprometido;
  final double ejecutado;
  final double saldoDisponible;
  final double porcentajeEjecucion;

  Partida({
    required this.id,
    required this.presupuestoId,
    required this.codigo,
    required this.nombre,
    required this.montoPlanificado,
    required this.comprometido,
    required this.ejecutado,
    required this.saldoDisponible,
    required this.porcentajeEjecucion,
  });

  factory Partida.fromJson(Map<String, dynamic> json) {
    return Partida(
      id: entero(json['id']),
      presupuestoId: entero(json['presupuestoId']),
      codigo: texto(json['codigo']),
      nombre: texto(json['nombre']),
      montoPlanificado: numero(json['montoPlanificado']),
      comprometido: numero(json['comprometido']),
      ejecutado: numero(json['ejecutado']),
      saldoDisponible: numero(json['saldoDisponible']),
      porcentajeEjecucion: numero(json['porcentajeEjecucion']),
    );
  }
}

class Seguimiento {
  final Presupuesto presupuesto;
  final List<Partida> partidas;

  Seguimiento({required this.presupuesto, required this.partidas});

  factory Seguimiento.fromJson(Map<String, dynamic> json) {
    return Seguimiento(
      presupuesto: Presupuesto.fromJson(mapa(json['presupuesto'])),
      partidas: lista<Partida>(json['partidas'], Partida.fromJson),
    );
  }
}

class Ejecucion {
  final int id;
  final int partidaId;
  final String partidaCodigo;
  final String partidaNombre;
  final String tipo; // COMPROMISO | EJECUCION
  final String fecha;
  final String concepto;
  final double monto;
  final int? activoId;
  final String? activoCodigo;
  final int? compromisoId;
  final bool liberado;
  final String? usuario;

  Ejecucion({
    required this.id,
    required this.partidaId,
    required this.partidaCodigo,
    required this.partidaNombre,
    required this.tipo,
    required this.fecha,
    required this.concepto,
    required this.monto,
    this.activoId,
    this.activoCodigo,
    this.compromisoId,
    required this.liberado,
    this.usuario,
  });

  factory Ejecucion.fromJson(Map<String, dynamic> json) {
    return Ejecucion(
      id: entero(json['id']),
      partidaId: entero(json['partidaId']),
      partidaCodigo: texto(json['partidaCodigo']),
      partidaNombre: texto(json['partidaNombre']),
      tipo: texto(json['tipo']),
      fecha: texto(json['fecha']),
      concepto: texto(json['concepto']),
      monto: numero(json['monto']),
      activoId: enteroOpc(json['activoId']),
      activoCodigo: textoOpc(json['activoCodigo']),
      compromisoId: enteroOpc(json['compromisoId']),
      liberado: json['liberado'] == true,
      usuario: textoOpc(json['usuario']),
    );
  }
}
