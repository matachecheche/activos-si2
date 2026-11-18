import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { CalculoDepreciacion, DepreciacionActivo, ResumenDepreciacion } from '../../core/models/sprint2.models';

@Injectable({ providedIn: 'root' })
export class DepreciacionService {
  private api = `${environment.apiUrl}/depreciacion`;

  constructor(private http: HttpClient) {}

  resumen(): Observable<ResumenDepreciacion[]> {
    return this.http.get<ResumenDepreciacion[]>(`${this.api}/resumen`);
  }

  tabla(activoId: number): Observable<DepreciacionActivo> {
    return this.http.get<DepreciacionActivo>(`${this.api}/activo/${activoId}`);
  }

  /** Calcula los periodos pendientes (idempotente) hasta el periodo yyyy-MM; por defecto el actual. */
  calcular(periodo?: string): Observable<CalculoDepreciacion> {
    let params = new HttpParams();
    if (periodo) params = params.set('periodo', periodo);
    return this.http.post<CalculoDepreciacion>(`${this.api}/calcular`, {}, { params });
  }

  calcularActivo(activoId: number, periodo?: string): Observable<CalculoDepreciacion> {
    let params = new HttpParams();
    if (periodo) params = params.set('periodo', periodo);
    return this.http.post<CalculoDepreciacion>(`${this.api}/activo/${activoId}/calcular`, {}, { params });
  }
}
