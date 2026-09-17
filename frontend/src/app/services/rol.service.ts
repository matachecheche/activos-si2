import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface Permiso { id: number; modulo: string; accion: string; descripcion: string; }
export interface Rol { id?: number; nombre: string; permisos: Permiso[]; }

@Injectable({ providedIn: 'root' })
export class RolService {
  private apiUrl = `${environment.apiUrl}/roles`;
  constructor(private http: HttpClient) {}
  listar(): Observable<Rol[]> { return this.http.get<Rol[]>(this.apiUrl); }
  permisos(): Observable<Permiso[]> { return this.http.get<Permiso[]>(`${this.apiUrl}/permisos`); }
  crear(rol: { nombre: string; permisos: number[] }): Observable<Rol> { return this.http.post<Rol>(this.apiUrl, rol); }
  actualizar(id: number, rol: { nombre: string; permisos: number[] }): Observable<Rol> { return this.http.put<Rol>(`${this.apiUrl}/${id}`, rol); }
  crearPermiso(permiso: Omit<Permiso, 'id'>): Observable<Permiso> { return this.http.post<Permiso>(`${this.apiUrl}/permisos`, permiso); }
  actualizarPermiso(id: number, permiso: Omit<Permiso, 'id'>): Observable<Permiso> { return this.http.put<Permiso>(`${this.apiUrl}/permisos/${id}`, permiso); }
  eliminarPermiso(id: number): Observable<void> { return this.http.delete<void>(`${this.apiUrl}/permisos/${id}`); }
}
