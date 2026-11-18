import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Asignacion } from '../../core/models/activo.model';

export interface AsignacionRequest {
  activoId: number;
  responsableId: number;
  ubicacionId: number;
}

export interface Responsable { id: number; nombre: string; correo: string; rol: string; }

@Injectable({ providedIn: 'root' })
export class AsignacionService {
  constructor(private http: HttpClient) {}

  asignar(req: AsignacionRequest): Observable<Asignacion> {
    return this.http.post<Asignacion>(`${environment.apiUrl}/asignaciones`, req);
  }

  historial(activoId: number): Observable<Asignacion[]> {
    return this.http.get<Asignacion[]>(`${environment.apiUrl}/asignaciones/activo/${activoId}`);
  }

  responsables(): Observable<Responsable[]> {
    return this.http.get<Responsable[]>(`${environment.apiUrl}/asignaciones/responsables`);
  }
}
