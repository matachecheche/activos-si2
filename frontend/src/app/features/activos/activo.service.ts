import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Activo, ActivoRequest, CambioEstadoRequest, HistorialEstado } from '../../core/models/activo.model';

@Injectable({ providedIn: 'root' })
export class ActivoService {
  private api = `${environment.apiUrl}/activos`;

  constructor(private http: HttpClient) {}

  listar(): Observable<Activo[]> {
    return this.http.get<Activo[]>(this.api);
  }

  obtener(id: number): Observable<Activo> {
    return this.http.get<Activo>(`${this.api}/${id}`);
  }

  /** HU-05: el QR contiene el codigo; al buscarlo se obtiene la ficha. */
  porCodigo(codigo: string): Observable<Activo> {
    return this.http.get<Activo>(`${this.api}/codigo/${encodeURIComponent(codigo.trim())}`);
  }

  registrar(activo: ActivoRequest): Observable<Activo> {
    return this.http.post<Activo>(this.api, activo);
  }

  actualizar(id: number, activo: ActivoRequest): Observable<Activo> {
    return this.http.put<Activo>(`${this.api}/${id}`, activo);
  }

  /** HU-06 */
  cambiarEstado(id: number, req: CambioEstadoRequest): Observable<Activo> {
    return this.http.post<Activo>(`${this.api}/${id}/estado`, req);
  }

  historialEstados(id: number): Observable<HistorialEstado[]> {
    return this.http.get<HistorialEstado[]>(`${this.api}/${id}/historial-estados`);
  }

  /** HU-05: imagen PNG del QR (se pide con el token, por eso se descarga como blob). */
  qr(id: number, tamano = 320): Observable<Blob> {
    return this.http.get(`${this.api}/${id}/qr`, { params: { tamano }, responseType: 'blob' });
  }

  etiquetaPdf(id: number): Observable<Blob> {
    return this.http.get(`${this.api}/${id}/etiqueta.pdf`, { responseType: 'blob' });
  }
}
