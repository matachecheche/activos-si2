import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface AsignacionRequest {
  activoId: number;
  responsableId: number;
  ubicacionId: number;
}

@Injectable({ providedIn: 'root' })
export class AsignacionService {
  constructor(private http: HttpClient) {}

  asignar(req: AsignacionRequest): Observable<any> {
    return this.http.post(`${environment.apiUrl}/asignaciones`, req);
  }

  historial(activoId: number): Observable<any[]> {
    return this.http.get<any[]>(`${environment.apiUrl}/asignaciones/activo/${activoId}`);
  }
}
