import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Respaldo, ProgramacionRespaldo } from '../../core/models/sprint3.models';

/** HU-16: respaldos manuales/programados con SHA-256 y restauracion transaccional. */
@Injectable({ providedIn: 'root' })
export class RespaldosService {
  private readonly base = `${environment.apiUrl}/respaldos`;

  constructor(private http: HttpClient) {}

  listar(): Observable<Respaldo[]> {
    return this.http.get<Respaldo[]>(this.base);
  }

  crear(): Observable<Respaldo> {
    return this.http.post<Respaldo>(this.base, {});
  }

  restaurar(id: number): Observable<Respaldo> {
    return this.http.post<Respaldo>(`${this.base}/${id}/restaurar`, {});
  }

  verProgramacion(): Observable<ProgramacionRespaldo> {
    return this.http.get<ProgramacionRespaldo>(`${this.base}/programacion`);
  }

  guardarProgramacion(prog: ProgramacionRespaldo): Observable<ProgramacionRespaldo> {
    return this.http.put<ProgramacionRespaldo>(`${this.base}/programacion`, prog);
  }
}
