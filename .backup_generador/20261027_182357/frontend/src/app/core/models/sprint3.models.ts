// Modelos de las funcionalidades del Sprint 3 (HU-11…HU-17).
// Los campos se declaran tolerantes (opcionales) porque varios endpoints
// responden Map<String,Object> en el backend.

export interface Plan {
  id: number;
  nombre: string;
  precioMensual: number;
  maxUsuarios?: number | null;
  maxActivos?: number | null;
  incluyeBi: boolean;
  incluyeConsultasDinamicas: boolean;
  respaldoProgramado: boolean;
  respaldoNube: boolean;
  idiomaAdicional: boolean;
  personalizacionCompleta: boolean;
  activo: boolean;
}

export interface RegistroEmpresaRequest {
  nombreEmpresa: string;
  nit: string;
  rubro?: string;
  correoContacto: string;
  planId: number;
  nombreAdmin: string;
  correoAdmin: string;
  passwordAdmin: string;
  metodoPago: 'TARJETA_SANDBOX' | 'TRANSFERENCIA';
  meses: number;
}

export interface Empresa {
  id: number;
  nombre: string;
  nit: string;
  rubro?: string;
  correoContacto?: string;
  estado: 'ACTIVA' | 'SUSPENDIDA' | string;
  fechaRegistro?: string;
}

export interface Respaldo {
  id: number;
  empresaId?: number;
  tipo: string;
  destino: string;
  archivo: string;
  /** Nombre del archivo para descargar (sin la ruta del servidor). */
  nombreArchivo?: string;
  tamanoBytes: number;
  sha256: string;
  estado: string;
  fecha: string;
}

export interface ProgramacionRespaldo {
  id?: number;
  frecuencia: 'DIARIA' | 'SEMANAL';
  hora: string;
  copiasAConservar: number;
  destino: 'LOCAL' | 'NUBE';
  activa: boolean;
}

export interface FiltroEspec {
  campo: string;
  operador: string;          // =, !=, >, >=, <, <=, LIKE, IN, BETWEEN
  valor?: unknown;
  valorHasta?: unknown;
  valores?: unknown[];
}

export interface OrdenEspec {
  campo: string;
  direccion: 'ASC' | 'DESC';
}

export interface AgregacionEspec {
  funcion: 'COUNT' | 'SUM' | 'AVG' | 'MIN' | 'MAX';
  campo: string;             // "*" solo para COUNT
  agruparPor?: string[];
}

/** Especificacion segura de consulta (whitelist anti-SQLi en el backend). */
export interface ConsultaEspec {
  entidad: string;
  columnas: string[];
  filtros?: FiltroEspec[];
  orden?: OrdenEspec[];
  limite?: number;
  agregacion?: AgregacionEspec | null;
}

export interface ResultadoConsulta {
  sql: string;
  columnas: string[];
  filas: Record<string, unknown>[];
}

export interface RespuestaIa {
  modo: 'GROQ' | 'GEMINI' | 'GUIADO';
  explicacion: string;
  sqlEjecutado?: string;
  columnas?: string[];
  filas?: Record<string, unknown>[];
  sugerencias?: string[];
  diagnostico?: string[];
}

export interface PruebaIa {
  proveedor: string;
  modelo: string;
  configurado: boolean;
  formatoClaveValido: boolean;
  ok: boolean;
  httpStatus: number;
  detalle: string;
}

export interface TurnoHistorialIa {
  rol: 'usuario' | 'asistente';
  texto: string;
}

export interface EstadoIa {
  groqConfigurado?: boolean;
  geminiConfigurado?: boolean;
  groqFormatoValido?: boolean;
  geminiFormatoValido?: boolean;
  modeloGroq?: string;
  modeloGemini?: string;
  fuente?: string;
  archivoConfig?: string | null;
}

export interface VistaMarca {
  colorPrimario: string;
  colorSecundario: string;
  idioma: 'es' | 'en';
  menuConfig: string;
  tieneLogo: boolean;
  logoNombre?: string;
  logoTipo?: string;
}

export interface VerificacionInventario {
  id: number;
  activoId: number;
  fechaHora: string;
  latitud?: number;
  longitud?: number;
  precisionM?: number;
  resultado: 'ENCONTRADO' | 'NO_ENCONTRADO' | 'DIFERENCIA_ESTADO' | string;
  fotoUrl?: string;
  observacion?: string;
}

export interface EntradaBitacora {
  id: number;
  empresaId?: number;
  usuarioNombre?: string;
  accion: string;
  entidad: string;
  entidadId?: string;
  detalle?: string;
  ip?: string;
  equipo?: string;
  fechaHora: string;
  hashRegistro: string;
  hashAnterior?: string;
}
