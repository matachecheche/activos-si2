import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Categoria, CategoriaRequest } from '../models/categoria.model';

@Injectable({ providedIn: 'root' })
export class CategoriaService {
  constructor(private http: HttpClient) {}

  listar(): Observable<Categoria[]> {
    return this.http.get<Categoria[]>(`${environment.apiUrl}/categorias`);
  }

  crear(req: CategoriaRequest): Observable<Categoria> {
    return this.http.post<Categoria>(`${environment.apiUrl}/categorias`, req);
  }

  /** HU-07: parametros de depreciacion por categoria. */
  actualizar(id: number, req: CategoriaRequest): Observable<Categoria> {
    return this.http.put<Categoria>(`${environment.apiUrl}/categorias/${id}`, req);
  }
}
