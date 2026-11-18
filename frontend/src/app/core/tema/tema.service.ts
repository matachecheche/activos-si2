import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject } from 'rxjs';
import { environment } from '../../../environments/environment';
import { IdiomaService } from '../i18n/idioma.service';

export interface VistaMarca {
  colorPrimario: string;
  colorSecundario: string;
  idioma: 'es' | 'en';
  menuConfig: string;
  tieneLogo: boolean;
  logoNombre?: string;
  logoTipo?: string;
}

export type PosicionMenu = 'LATERAL' | 'SUPERIOR';

/**
 * HU-15: aplica la personalizacion de la empresa (colores, logo, idioma,
 * posicion del menu) como variables CSS sobre :root. Sin librerias de temas.
 */
@Injectable({ providedIn: 'root' })
export class TemaService {
  private posicion$ = new BehaviorSubject<PosicionMenu>('SUPERIOR');
  posicionMenu = this.posicion$.asObservable();
  private marca: VistaMarca | null = null;

  constructor(private http: HttpClient, private idioma: IdiomaService) {}

  cargar(): void {
    this.http.get<VistaMarca>(`${environment.apiUrl}/configuracion`).subscribe({
      next: (marca) => this.aplicar(marca),
      error: () => { /* sin sesion o sin personalizacion: se usan los valores por defecto */ }
    });
  }

  aplicar(marca: VistaMarca): void {
    this.marca = marca;
    const root = document.documentElement.style;
    if (marca.colorPrimario) root.setProperty('--color-primario', marca.colorPrimario);
    if (marca.colorSecundario) root.setProperty('--color-secundario', marca.colorSecundario);
    if (marca.idioma) this.idioma.cambiar(marca.idioma);
    this.posicion$.next(this.leerPosicion(marca.menuConfig));
  }

  obtener(): VistaMarca | null {
    return this.marca;
  }

  private leerPosicion(menuConfig: string | undefined): PosicionMenu {
    if (!menuConfig) return 'SUPERIOR';
    try {
      const arreglo = JSON.parse(menuConfig);
      const primera = Array.isArray(arreglo) ? arreglo[0]?.posicion : null;
      return primera === 'LATERAL' ? 'LATERAL' : 'SUPERIOR';
    } catch {
      return 'SUPERIOR';
    }
  }
}
