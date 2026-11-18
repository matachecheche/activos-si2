export type EstadoActivo = 'DISPONIBLE' | 'EN_USO' | 'EN_MANTENIMIENTO' | 'INACTIVO' | 'DADO_DE_BAJA';

export interface UsuarioRef { id: number; nombre: string; correo: string; }
export interface UbicacionRef { id: number; nombre: string; }

/** Respuesta del backend (la categoria llega plana y tambien anidada). */
export interface Activo {
  id: number;
  codigo: string;
  nombre: string;
  categoriaId: number;
  categoriaNombre: string;
  valor: number;
  valorResidual?: number | null;
  fechaAdquisicion: string;
  fechaInicioDepreciacion?: string | null;
  fechaBaja?: string | null;
  proveedor?: string | null;
  observaciones?: string | null;
  estado: EstadoActivo;
  estadoEtiqueta: string;
  responsable?: UsuarioRef | null;
  ubicacion?: UbicacionRef | null;
  estadosPermitidos: string[];
  editable?: boolean | null;
}

export interface ActivoRequest {
  nombre: string;
  categoriaId: number;
  valor: number;
  fechaAdquisicion: string;
  proveedor?: string | null;
  observaciones?: string | null;
  valorResidual?: number | null;
  fechaInicioDepreciacion?: string | null;
}

export interface CambioEstadoRequest { estado: string; motivo: string; }

export interface HistorialEstado {
  id: number;
  estadoAnterior?: string | null;
  estadoAnteriorEtiqueta?: string | null;
  estadoNuevo: string;
  estadoNuevoEtiqueta: string;
  motivo: string;
  usuario: string;
  fecha: string;
}

export interface Asignacion {
  id: number;
  activoId: number;
  activoCodigo: string;
  responsable: UsuarioRef;
  ubicacion: UbicacionRef;
  fechaAsignacion: string;
  activa: boolean;
}
