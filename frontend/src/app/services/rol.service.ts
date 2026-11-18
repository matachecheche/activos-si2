import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface Permiso { id: number; modulo: string; accion: string; descripcion: string; }
export interface Rol {
  id?: number;
  nombre: string;
  descripcion?: string | null;
  activo?: boolean;
  permisos: Permiso[];
  usuariosActivos?: number;
}
export interface RolPayload { nombre: string; descripcion?: string | null; permisos: number[]; activo?: boolean; }
export interface RolOpcion { id: number; nombre: string; descripcion?: string | null; }

@Injectable({ providedIn: 'root' })
export class RolService {
  private apiUrl = `${environment.apiUrl}/roles`;
  constructor(private http: HttpClient) {}
  listar(): Observable<Rol[]> { return this.http.get<Rol[]>(this.apiUrl); }
  /** Roles activos que se pueden asignar a un usuario. */
  disponibles(): Observable<RolOpcion[]> { return this.http.get<RolOpcion[]>(`${this.apiUrl}/disponibles`); }
  permisos(): Observable<Permiso[]> { return this.http.get<Permiso[]>(`${this.apiUrl}/permisos`); }
  crear(rol: RolPayload): Observable<Rol> { return this.http.post<Rol>(this.apiUrl, rol); }
  actualizar(id: number, rol: RolPayload): Observable<Rol> { return this.http.put<Rol>(`${this.apiUrl}/${id}`, rol); }
  /** Desactiva el rol (el backend lo rechaza si tiene usuarios activos asignados). */
  desactivar(id: number): Observable<Rol> { return this.http.delete<Rol>(`${this.apiUrl}/${id}`); }
  crearPermiso(permiso: Omit<Permiso, 'id'>): Observable<Permiso> { return this.http.post<Permiso>(`${this.apiUrl}/permisos`, permiso); }
  actualizarPermiso(id: number, permiso: Omit<Permiso, 'id'>): Observable<Permiso> { return this.http.put<Permiso>(`${this.apiUrl}/permisos/${id}`, permiso); }
  eliminarPermiso(id: number): Observable<void> { return this.http.delete<void>(`${this.apiUrl}/permisos/${id}`); }
}
