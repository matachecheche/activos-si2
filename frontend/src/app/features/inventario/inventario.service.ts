import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { VerificacionInventario } from '../../core/models/sprint3.models';

interface Pagina<T> {
  content: T[];
  totalElements: number;
  number: number;
  size: number;
}

/** HU-17: verificacion de inventario con GPS, evidencia fotografica y estadisticas. */
@Injectable({ providedIn: 'root' })
export class InventarioService {
  private readonly base = `${environment.apiUrl}/inventario`;

  constructor(private http: HttpClient) {}

  verificar(req: {
    activoId: number;
    resultado: string;
    latitud?: number | null;
    longitud?: number | null;
    precisionM?: number | null;
    observacion?: string;
    fotoUrl?: string;
  }): Observable<VerificacionInventario> {
    return this.http.post<VerificacionInventario>(`${this.base}/verificaciones`, req);
  }

  listar(pagina = 0, tamano = 20): Observable<Pagina<VerificacionInventario>> {
    const params = new HttpParams().set('pagina', String(pagina)).set('tamano', String(tamano));
    return this.http.get<Pagina<VerificacionInventario>>(`${this.base}/verificaciones`, { params });
  }

  estadisticas(): Observable<Record<string, number>> {
    return this.http.get<Record<string, number>>(`${this.base}/estadisticas`);
  }

  subirFoto(archivo: File): Observable<{ fotoUrl: string }> {
    const form = new FormData();
    form.append('foto', archivo);
    return this.http.post<{ fotoUrl: string }>(`${this.base}/foto`, form);
  }
}
