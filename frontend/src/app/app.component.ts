import { Component, HostListener, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { filter } from 'rxjs';
import { AuthService } from './core/auth/auth.service';
import { TemaService, PosicionMenu } from './core/tema/tema.service';
import { IdiomaService, Idioma, TraduccionPipe } from './core/i18n/idioma.service';
import { environment } from '../environments/environment';
import { ItemMenu } from './core/menu';
import { EmpresaSesion } from './core/auth/auth.service';
import { mensajeError } from './core/util/http-error';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive, TraduccionPipe],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent implements OnInit {
  posicion: PosicionMenu = 'SUPERIOR';
  idioma: Idioma = 'es';
  /** Sprint 3 / multiempresa: empresas a las que el usuario tiene acceso. */
  empresas: EmpresaSesion[] = [];
  selectorAbierto = false;
  cambiando = false;
  /** Ronda 11: mensaje real del servidor al cambiar de empresa. */
  mensajeError = '';
  private temaCargado = false;

  constructor(
    public authService: AuthService,
    private router: Router,
    public tema: TemaService,
    private idiomaService: IdiomaService
  ) {
    this.idiomaService.idiomaActual.subscribe((idioma) => (this.idioma = idioma));
    this.tema.posicionMenu.subscribe((posicion) => (this.posicion = posicion));
  }

  ngOnInit(): void {
    this.cargarTemaUnaVez();
    this.cargarEmpresas();
    // Tras un nuevo inicio de sesion se carga la personalizacion de la empresa.
    this.router.events.pipe(filter((e) => e instanceof NavigationEnd)).subscribe((e) => {
      const fin = e as NavigationEnd;
      if (fin.urlAfterRedirects.startsWith('/login')) {
        this.temaCargado = false;
      } else {
        this.cargarTemaUnaVez();
      }
    });
  }

  /** Carga la lista de empresas del usuario (multiempresa). */
  private cargarEmpresas(): void {
    if (!this.authService.isLoggedIn()) {
      this.empresas = [];
      return;
    }
    this.authService.misEmpresas().subscribe({
      next: (lista) => (this.empresas = lista || []),
      error: () => (this.empresas = this.authService.getEmpresas())
    });
  }

  /**
   * Cambia de empresa: el backend emite un token nuevo y se recarga la app.
   *
   * Ronda 11: antes se mostraba un mensaje generico ("No se pudo cambiar de
   * empresa. Intenta de nuevo.") que no explicaba nada. Ahora se muestra el
   * motivo real del servidor (permiso, empresa inexistente, sesion vencida...)
   * y el menu vuelve a quedar abierto para reintentar.
   */
  cambiarEmpresa(empresa: EmpresaSesion): void {
    if (this.cambiando || !empresa.empresaId) return;
    this.cambiando = true;
    this.selectorAbierto = false;
    this.mensajeError = '';
    this.authService.cambiarEmpresaSeguro(empresa.empresaId).subscribe({
      next: () => window.location.reload(),
      error: (err) => {
        this.cambiando = false;
        this.mensajeError = `No se pudo cambiar a "${empresa.empresaNombre}": ${mensajeError(
          err,
          'el servidor no respondio como se esperaba'
        )}`;
        this.selectorAbierto = true;
      }
    });
  }

  /** Abre el formulario para registrar otra empresa a la cuenta del usuario. */
  agregarEmpresa(): void {
    this.selectorAbierto = false;
    this.router.navigate(['/registro-empresa']);
  }

  private cargarTemaUnaVez(): void {
    if (!this.temaCargado && this.authService.isLoggedIn()) {
      this.temaCargado = true;
      this.tema.cargar();
    }
  }

  get esLateral(): boolean {
    return this.posicion === 'LATERAL';
  }

  get logoUrl(): string {
    return `${environment.apiUrl}/configuracion/logo?ts=${Date.now()}`;
  }

  get itemsMenu(): ItemMenu[] {
    return this.authService.menu();
  }

  cambiarIdioma(): void {
    this.idiomaService.cambiar(this.idioma === 'es' ? 'en' : 'es');
  }

  etiqueta(item: ItemMenu): string {
    return item.claveI18n ? this.idiomaService.traducir(item.claveI18n) : item.etiqueta;
  }

  cerrarSesion(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  @HostListener('window:click') onActivity(): void { this.authService.registrarActividad(); }
  @HostListener('window:keydown') onKeyActivity(): void { this.authService.registrarActividad(); }
}
