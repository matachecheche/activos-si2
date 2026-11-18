export interface Categoria {
  id: number;
  nombre: string;
  vidaUtil?: number | null;          // en años
  metodoDepreciacion?: string | null;
  valorResidualPct?: number | null;
  depreciable?: boolean;
}

export interface CategoriaRequest {
  nombre: string;
  vidaUtil?: number | null;
  valorResidualPct?: number | null;
  depreciable: boolean;
  metodoDepreciacion?: string | null;
}
