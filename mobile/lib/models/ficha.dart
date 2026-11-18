// Modelos del Sprint 2 usados en la ficha del activo y en los modulos de depreciacion y mantenimientos.
import 'json_util.dart';

// ---------------- HU-07 depreciacion ----------------

class ResumenDepreciacion {
  final int activoId;
  final String codigo;
  final String nombre;
  final String categoria;
  final String estado;
  final bool depreciable;
  final String? observacion;
  final double valorAdquisicion;
  final double valorResidual;
  final int? vidaUtilAnios;
  final int? vidaUtilMeses;
  final double depreciacionMensual;
  final double depreciacionAcumulada;
  final double valorEnLibros;
  final int periodosCalculados;
  final String? ultimoPeriodo;

  ResumenDepreciacion({
    required this.activoId,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.estado,
    required this.depreciable,
    this.observacion,
    required this.valorAdquisicion,
    required this.valorResidual,
    this.vidaUtilAnios,
    this.vidaUtilMeses,
    required this.depreciacionMensual,
    required this.depreciacionAcumulada,
    required this.valorEnLibros,
    required this.periodosCalculados,
    this.ultimoPeriodo,
  });

  factory ResumenDepreciacion.fromJson(Map<String, dynamic> json) {
    return ResumenDepreciacion(
      activoId: entero(json['activoId']),
      codigo: texto(json['codigo']),
      nombre: texto(json['nombre']),
      categoria: texto(json['categoria']),
      estado: texto(json['estado']),
      depreciable: json['depreciable'] == true,
      observacion: textoOpc(json['observacion']),
      valorAdquisicion: numero(json['valorAdquisicion']),
      valorResidual: numero(json['valorResidual']),
      vidaUtilAnios: enteroOpc(json['vidaUtilAnios']),
      vidaUtilMeses: enteroOpc(json['vidaUtilMeses']),
      depreciacionMensual: numero(json['depreciacionMensual']),
      depreciacionAcumulada: numero(json['depreciacionAcumulada']),
      valorEnLibros: numero(json['valorEnLibros']),
      periodosCalculados: entero(json['periodosCalculados']),
      ultimoPeriodo: textoOpc(json['ultimoPeriodo']),
    );
  }
}

class FilaDepreciacion {
  final String periodo;
  final double depreciacionPeriodo;
  final double depreciacionAcumulada;
  final double valorEnLibros;

  FilaDepreciacion({
    required this.periodo,
    required this.depreciacionPeriodo,
    required this.depreciacionAcumulada,
    required this.valorEnLibros,
  });

  factory FilaDepreciacion.fromJson(Map<String, dynamic> json) {
    return FilaDepreciacion(
      periodo: texto(json['periodo']),
      depreciacionPeriodo: numero(json['depreciacionPeriodo']),
      depreciacionAcumulada: numero(json['depreciacionAcumulada']),
      valorEnLibros: numero(json['valorEnLibros']),
    );
  }
}

class DepreciacionActivo {
  final ResumenDepreciacion resumen;
  final List<FilaDepreciacion> filas;

  DepreciacionActivo({required this.resumen, required this.filas});

  factory DepreciacionActivo.fromJson(Map<String, dynamic> json) {
    return DepreciacionActivo(
      resumen: ResumenDepreciacion.fromJson(mapa(json['resumen'])),
      filas: lista<FilaDepreciacion>(json['filas'], FilaDepreciacion.fromJson),
    );
  }
}

class CalculoDepreciacion {
  final String hasta;
  final int activosProcesados;
  final int periodosGenerados;

  CalculoDepreciacion({required this.hasta, required this.activosProcesados, required this.periodosGenerados});

  factory CalculoDepreciacion.fromJson(Map<String, dynamic> json) {
    return CalculoDepreciacion(
      hasta: texto(json['hasta']),
      activosProcesados: entero(json['activosProcesados']),
      periodosGenerados: entero(json['periodosGenerados']),
    );
  }
}

// ---------------- HU-08 mantenimiento ----------------

class Mantenimiento {
  final int id;
  final int activoId;
  final String activoCodigo;
  final String activoNombre;
  final String tipo; // PREVENTIVO | CORRECTIVO
  final String estado; // PROGRAMADO | EN_EJECUCION | FINALIZADO | CANCELADO
  final String? descripcion;
  final String? fechaProgramada;
  final int? periodicidadDias;
  final String? fechaInicio;
  final String? fechaRealizada;
  final double? costo;
  final String? tecnico;
  final String? observaciones;
  final int? diasParaVencer;

  Mantenimiento({
    required this.id,
    required this.activoId,
    required this.activoCodigo,
    required this.activoNombre,
    required this.tipo,
    required this.estado,
    this.descripcion,
    this.fechaProgramada,
    this.periodicidadDias,
    this.fechaInicio,
    this.fechaRealizada,
    this.costo,
    this.tecnico,
    this.observaciones,
    this.diasParaVencer,
  });

  factory Mantenimiento.fromJson(Map<String, dynamic> json) {
    return Mantenimiento(
      id: entero(json['id']),
      activoId: entero(json['activoId']),
      activoCodigo: texto(json['activoCodigo']),
      activoNombre: texto(json['activoNombre']),
      tipo: texto(json['tipo']),
      estado: texto(json['estado']),
      descripcion: textoOpc(json['descripcion']),
      fechaProgramada: textoOpc(json['fechaProgramada']),
      periodicidadDias: enteroOpc(json['periodicidadDias']),
      fechaInicio: textoOpc(json['fechaInicio']),
      fechaRealizada: textoOpc(json['fechaRealizada']),
      costo: numeroOpc(json['costo']),
      tecnico: textoOpc(json['tecnico']),
      observaciones: textoOpc(json['observaciones']),
      diasParaVencer: enteroOpc(json['diasParaVencer']),
    );
  }

  /// Texto de vencimiento: "vencido hace 3 dia(s)", "vence hoy", "en 5 dia(s)".
  String get textoDias {
    final d = diasParaVencer;
    if (d == null) return '';
    if (d < 0) return 'vencido hace ${-d} día(s)';
    if (d == 0) return 'vence hoy';
    return 'en $d día(s)';
  }
}

class MantenimientoActivo {
  final List<Mantenimiento> items;
  final double costoTotal;

  MantenimientoActivo({required this.items, required this.costoTotal});

  factory MantenimientoActivo.fromJson(Map<String, dynamic> json) {
    return MantenimientoActivo(
      items: lista<Mantenimiento>(json['items'], Mantenimiento.fromJson),
      costoTotal: numero(json['costoTotal']),
    );
  }
}

class AlertasMantenimiento {
  final List<Mantenimiento> proximos;
  final List<Mantenimiento> vencidos;

  AlertasMantenimiento({required this.proximos, required this.vencidos});

  factory AlertasMantenimiento.fromJson(Map<String, dynamic> json) {
    return AlertasMantenimiento(
      proximos: lista<Mantenimiento>(json['proximos'], Mantenimiento.fromJson),
      vencidos: lista<Mantenimiento>(json['vencidos'], Mantenimiento.fromJson),
    );
  }
}
