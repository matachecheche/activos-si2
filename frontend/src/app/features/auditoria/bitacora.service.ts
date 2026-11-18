import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { EntradaBitacora } from '../../core/models/sprint3.models';

interface Pagina<T> {
  content: T[];
  totalElements: number;
  number: number;
  size: number;
}

/** HU-13: bitacora inmutable (solo INSERT/SELECT) y verificacion de cadena de hashes. */
@Injectable({ providedIn: 'root' })
export class BitacoraService {
  private readonly base = `${environment.apiUrl}/auditoria`;

  constructor(private http: HttpClient) {}

  buscar(filtros: { usuario?: string; accion?: string; entidad?: string; pagina: number; tamano: number }): Observable<Pagina<EntradaBitacora>> {
    let params = new HttpParams()
      .set('pagina', String(filtros.pagina))
      .set('tamano', String(filtros.tamano));
    if (filtros.usuario) params = params.set('usuario', filtros.usuario);
    if (filtros.accion) params = params.set('accion', filtros.accion);
    if (filtros.entidad) params = params.set('entidad', filtros.entidad);
    return this.http.get<Pagina<EntradaBitacora>>(this.base, { params });
  }

  verificarIntegridad(): Observable<{ integra: boolean; registrosAlterados: number }> {
    return this.http.post<{ integra: boolean; registrosAlterados: number }>(`${this.base}/verificar`, {});
  }
}
