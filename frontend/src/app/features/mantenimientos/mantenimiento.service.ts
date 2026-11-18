import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  AlertasMantenimiento, Mantenimiento, MantenimientoActivo, MantenimientoFinalizarRequest, MantenimientoRequest
} from '../../core/models/sprint2.models';

@Injectable({ providedIn: 'root' })
export class MantenimientoService {
  private api = `${environment.apiUrl}/mantenimientos`;

  constructor(private http: HttpClient) {}

  listar(activoId?: number | null, estado?: string | null): Observable<Mantenimiento[]> {
    let params = new HttpParams();
    if (activoId) params = params.set('activoId', activoId);
    if (estado) params = params.set('estado', estado);
    return this.http.get<Mantenimiento[]>(this.api, { params });
  }

  alertas(): Observable<AlertasMantenimiento> {
    return this.http.get<AlertasMantenimiento>(`${this.api}/alertas`);
  }

  porActivo(activoId: number): Observable<MantenimientoActivo> {
    return this.http.get<MantenimientoActivo>(`${environment.apiUrl}/activos/${activoId}/mantenimientos`);
  }

  programar(req: MantenimientoRequest): Observable<Mantenimiento> {
    return this.http.post<Mantenimiento>(this.api, req);
  }

  actualizar(id: number, req: MantenimientoRequest): Observable<Mantenimiento> {
    return this.http.put<Mantenimiento>(`${this.api}/${id}`, req);
  }

  iniciar(id: number): Observable<Mantenimiento> {
    return this.http.post<Mantenimiento>(`${this.api}/${id}/iniciar`, {});
  }

  finalizar(id: number, req: MantenimientoFinalizarRequest): Observable<Mantenimiento> {
    return this.http.post<Mantenimiento>(`${this.api}/${id}/finalizar`, req);
  }

  cancelar(id: number, motivo: string): Observable<Mantenimiento> {
    return this.http.post<Mantenimiento>(`${this.api}/${id}/cancelar`, { motivo });
  }
}
