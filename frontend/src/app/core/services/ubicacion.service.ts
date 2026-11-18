import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Ubicacion } from '../models/sprint2.models';

@Injectable({ providedIn: 'root' })
export class UbicacionService {
  constructor(private http: HttpClient) {}

  listar(): Observable<Ubicacion[]> {
    return this.http.get<Ubicacion[]>(`${environment.apiUrl}/ubicaciones`);
  }

  crear(nombre: string, areaId?: number | null): Observable<Ubicacion> {
    return this.http.post<Ubicacion>(`${environment.apiUrl}/ubicaciones`, { nombre, areaId: areaId ?? null });
  }
}
