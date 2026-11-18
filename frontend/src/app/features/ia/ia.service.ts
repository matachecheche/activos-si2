import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ConsultaEspec, EstadoIa, PruebaIa, RespuestaIa, ResultadoConsulta, TurnoHistorialIa } from '../../core/models/sprint3.models';

/**
 * HU-14: asistente en lenguaje natural. Groq es el proveedor principal,
 * Gemini el respaldo y, sin clave API, el backend responde en modo GUIADO.
 */
@Injectable({ providedIn: 'root' })
export class IaService {
  constructor(private http: HttpClient) {}

  preguntar(pregunta: string, historial?: TurnoHistorialIa[]): Observable<RespuestaIa> {
    return this.http.post<RespuestaIa>(`${environment.apiUrl}/ia/consulta`, { pregunta, historial });
  }

  /** Ejecuta una especificacion armada a mano (constructor seguro, whitelist server-side). */
  ejecutar(espec: ConsultaEspec): Observable<ResultadoConsulta> {
    return this.http.post<ResultadoConsulta>(`${environment.apiUrl}/ia/ejecutar`, espec);
  }

  catalogo(): Observable<unknown> {
    return this.http.get(`${environment.apiUrl}/ia/catalogo`);
  }

  /** Diagnostico de claves: permite saber si el backend recibio la configuracion. */
  estado(): Observable<EstadoIa> {
    return this.http.get<EstadoIa>(`${environment.apiUrl}/ia/estado`);
  }

  /** Prueba en vivo contra Groq y Gemini; devuelve el detalle tecnico de cada intento. */
  probar(): Observable<PruebaIa[]> {
    return this.http.post<PruebaIa[]>(`${environment.apiUrl}/ia/probar`, {});
  }
}
