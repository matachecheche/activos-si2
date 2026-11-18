import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { VistaMarca } from '../../core/models/sprint3.models';
import { TemaService } from '../../core/tema/tema.service';

/** HU-15: colores, logo (max 1 MB), idioma es/en y posicion del menu. */
@Injectable({ providedIn: 'root' })
export class PersonalizacionService {
  private readonly base = `${environment.apiUrl}/configuracion`;
  readonly tamanoMaximoLogo = 1024 * 1024; // 1 MB

  constructor(private http: HttpClient, private tema: TemaService) {}

  ver(): Observable<VistaMarca> {
    return this.http.get<VistaMarca>(this.base);
  }

  guardar(body: { colorPrimario: string; colorSecundario: string; idioma: string; menuConfig: string }): Observable<unknown> {
    return this.http.put(this.base, body);
  }

  subirLogo(archivo: File): Observable<VistaMarca> {
    if (archivo.size > this.tamanoMaximoLogo) {
      throw new Error('El logo no puede superar 1 MB');
    }
    const form = new FormData();
    form.append('logo', archivo);
    return new Observable((observer) => {
      this.http.post<VistaMarca>(`${this.base}/logo`, form).subscribe({
        next: (marca) => {
          this.tema.aplicar(marca);
          observer.next(marca);
          observer.complete();
        },
        error: (e) => observer.error(e)
      });
    });
  }

  quitarLogo(): Observable<unknown> {
    return this.http.delete(`${this.base}/logo`);
  }

  urlLogo(): string {
    return `${this.base}/logo?ts=${Date.now()}`;
  }
}
