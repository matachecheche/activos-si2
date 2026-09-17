import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Activo } from '../../core/models/activo.model';

@Injectable({ providedIn: 'root' })
export class ActivoService {
  constructor(private http: HttpClient) {}

  listar(): Observable<Activo[]> {
    return this.http.get<Activo[]>(`${environment.apiUrl}/activos`);
  }

  registrar(activo: Activo): Observable<Activo> {
    return this.http.post<Activo>(`${environment.apiUrl}/activos`, activo);
  }

  actualizar(id: number, activo: Activo): Observable<Activo> {
    return this.http.put<Activo>(`${environment.apiUrl}/activos/${id}`, activo);
  }
}
