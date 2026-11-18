export interface Ubicacion { id: number; nombre: string; areaId?: number | null; areaNombre?: string | null; }
export interface Area { id: number; nombre: string; descripcion?: string | null; activo: boolean; }

// ---- HU-07 depreciacion ----
export interface ResumenDepreciacion {
  activoId: number;
  codigo: string;
  nombre: string;
  categoria: string;
  estado: string;
  depreciable: boolean;
  observacion?: string | null;
  valorAdquisicion: number;
  valorResidual: number;
  vidaUtilAnios?: number | null;
  vidaUtilMeses?: number | null;
  depreciacionMensual: number;
  depreciacionAcumulada: number;
  valorEnLibros: number;
  periodosCalculados: number;
  ultimoPeriodo?: string | null;
}
export interface FilaDepreciacion {
  periodo: string;
  depreciacionPeriodo: number;
  depreciacionAcumulada: number;
  valorEnLibros: number;
}
export interface DepreciacionActivo { resumen: ResumenDepreciacion; filas: FilaDepreciacion[]; }
export interface CalculoDepreciacion { hasta: string; activosProcesados: number; periodosGenerados: number; }

// ---- HU-08 mantenimiento ----
export type TipoMantenimiento = 'PREVENTIVO' | 'CORRECTIVO';
export interface Mantenimiento {
  id: number;
  activoId: number;
  activoCodigo: string;
  activoNombre: string;
  tipo: TipoMantenimiento;
  estado: 'PROGRAMADO' | 'EN_EJECUCION' | 'FINALIZADO' | 'CANCELADO';
  descripcion?: string | null;
  fechaProgramada?: string | null;
  periodicidadDias?: number | null;
  fechaInicio?: string | null;
  fechaRealizada?: string | null;
  costo?: number | null;
  tecnico?: string | null;
  observaciones?: string | null;
  diasParaVencer?: number | null;
}
export interface MantenimientoRequest {
  activoId: number;
  tipo: TipoMantenimiento;
  descripcion?: string | null;
  fechaProgramada?: string | null;
  periodicidadDias?: number | null;
}
export interface MantenimientoFinalizarRequest {
  fechaRealizada?: string | null;
  costo: number;
  tecnico: string;
  observaciones?: string | null;
}
export interface MantenimientoActivo { items: Mantenimiento[]; costoTotal: number; }
export interface AlertasMantenimiento { proximos: Mantenimiento[]; vencidos: Mantenimiento[]; }

// ---- HU-09 / HU-10 presupuestos ----
export interface Presupuesto {
  id: number;
  areaId: number;
  areaNombre: string;
  gestion: number;
  montoAprobado: number;
  estado: 'BORRADOR' | 'APROBADO' | 'CERRADO';
  fechaAprobacion?: string | null;
  aprobador?: string | null;
  montoPlanificado: number;
  sinDistribuir: number;
  comprometido: number;
  ejecutado: number;
  saldoDisponible: number;
  porcentajeEjecucion: number;
}
export interface PresupuestoRequest { areaId: number; gestion: number; montoAprobado: number; }
export interface Partida {
  id: number;
  presupuestoId: number;
  codigo: string;
  nombre: string;
  montoPlanificado: number;
  comprometido: number;
  ejecutado: number;
  saldoDisponible: number;
  porcentajeEjecucion: number;
}
export interface PartidaRequest { codigo: string; nombre: string; montoPlanificado: number; }
export interface Seguimiento { presupuesto: Presupuesto; partidas: Partida[]; }
export interface Ejecucion {
  id: number;
  partidaId: number;
  partidaCodigo: string;
  partidaNombre: string;
  tipo: 'COMPROMISO' | 'EJECUCION';
  fecha: string;
  concepto: string;
  monto: number;
  activoId?: number | null;
  activoCodigo?: string | null;
  compromisoId?: number | null;
  liberado: boolean;
  usuario?: string | null;
}
export interface EjecucionRequest {
  partidaId: number;
  tipo: 'COMPROMISO' | 'EJECUCION';
  fecha: string;
  concepto: string;
  monto: number;
  activoId?: number | null;
  compromisoId?: number | null;
}
