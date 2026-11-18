import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ConsultaEspec, ResultadoConsulta } from '../../core/models/sprint3.models';

/** HU-14: reportes con filtros, exportaciones y tablero BI; HU-13: consultas guardadas. */
@Injectable({ providedIn: 'root' })
export class ReportesService {
  constructor(private http: HttpClient) {}

  consultar(espec: ConsultaEspec): Observable<ResultadoConsulta> {
    return this.http.post<ResultadoConsulta>(`${environment.apiUrl}/reportes/consultar`, espec);
  }

  tableroBi(): Observable<Record<string, unknown>> {
    return this.http.get<Record<string, unknown>>(`${environment.apiUrl}/reportes/bi`);
  }

  catalogo(): Observable<unknown> {
    return this.http.get(`${environment.apiUrl}/ia/catalogo`);
  }

  listarGuardadas(): Observable<Array<{ id: number; nombre: string; entidad: string; definicion: string }>> {
    return this.http.get<Array<{ id: number; nombre: string; entidad: string; definicion: string }>>(
      `${environment.apiUrl}/consultas-guardadas`
    );
  }

  guardar(nombre: string, entidad: string, definicion: string): Observable<unknown> {
    return this.http.post(`${environment.apiUrl}/consultas-guardadas`, { nombre, entidad, definicion });
  }

  ejecutarGuardada(id: number): Observable<ResultadoConsulta> {
    return this.http.get<ResultadoConsulta>(`${environment.apiUrl}/consultas-guardadas/${id}/ejecutar`);
  }

  eliminarGuardada(id: number): Observable<unknown> {
    return this.http.delete(`${environment.apiUrl}/consultas-guardadas/${id}`);
  }
}
