import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  Area, Ejecucion, EjecucionRequest, Partida, PartidaRequest, Presupuesto, PresupuestoRequest, Seguimiento
} from '../../core/models/sprint2.models';

@Injectable({ providedIn: 'root' })
export class PresupuestoService {
  private api = `${environment.apiUrl}/presupuestos`;

  constructor(private http: HttpClient) {}

  listar(gestion?: number | null, areaId?: number | null): Observable<Presupuesto[]> {
    let params = new HttpParams();
    if (gestion) params = params.set('gestion', gestion);
    if (areaId) params = params.set('areaId', areaId);
    return this.http.get<Presupuesto[]>(this.api, { params });
  }

  obtener(id: number): Observable<Presupuesto> { return this.http.get<Presupuesto>(`${this.api}/${id}`); }
  crear(req: PresupuestoRequest): Observable<Presupuesto> { return this.http.post<Presupuesto>(this.api, req); }
  actualizar(id: number, req: PresupuestoRequest): Observable<Presupuesto> { return this.http.put<Presupuesto>(`${this.api}/${id}`, req); }
  aprobar(id: number): Observable<Presupuesto> { return this.http.post<Presupuesto>(`${this.api}/${id}/aprobar`, {}); }
  cerrar(id: number): Observable<Presupuesto> { return this.http.post<Presupuesto>(`${this.api}/${id}/cerrar`, {}); }
  eliminar(id: number): Observable<void> { return this.http.delete<void>(`${this.api}/${id}`); }

  seguimiento(id: number): Observable<Seguimiento> { return this.http.get<Seguimiento>(`${this.api}/${id}/seguimiento`); }

  crearPartida(id: number, req: PartidaRequest): Observable<Partida> { return this.http.post<Partida>(`${this.api}/${id}/partidas`, req); }
  actualizarPartida(id: number, partidaId: number, req: PartidaRequest): Observable<Partida> {
    return this.http.put<Partida>(`${this.api}/${id}/partidas/${partidaId}`, req);
  }
  eliminarPartida(id: number, partidaId: number): Observable<void> { return this.http.delete<void>(`${this.api}/${id}/partidas/${partidaId}`); }

  ejecuciones(id: number): Observable<Ejecucion[]> { return this.http.get<Ejecucion[]>(`${this.api}/${id}/ejecuciones`); }
  registrarEjecucion(req: EjecucionRequest): Observable<Ejecucion> { return this.http.post<Ejecucion>(`${environment.apiUrl}/ejecuciones`, req); }

  areas(): Observable<Area[]> { return this.http.get<Area[]>(`${environment.apiUrl}/areas`); }
  crearArea(nombre: string, descripcion?: string): Observable<Area> {
    return this.http.post<Area>(`${environment.apiUrl}/areas`, { nombre, descripcion: descripcion ?? null });
  }
}
