export interface Activo {
  id?: number;
  codigo?: string;
  nombre: string;
  categoriaId: number;
  valor: number;
  fechaAdquisicion: string;
  proveedor?: string;
  observaciones?: string;
  estado?: string;
}
