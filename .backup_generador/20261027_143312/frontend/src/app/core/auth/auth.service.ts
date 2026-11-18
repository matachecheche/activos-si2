import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ItemMenu, MENU } from '../menu';

interface LoginResponse {
  token: string;
  nombre: string;
  rol: string;
  permisos: string[];
  empresaId?: number | null;
  nivel?: string;
  empresaNombre?: string | null;
  /** Sprint 3 / multiempresa: empresas a las que el usuario tiene acceso. */
  empresas?: EmpresaSesion[];
}

/** Una empresa a la que el usuario tiene acceso, con su rol en ella. */
export interface EmpresaSesion {
  empresaId: number;
  empresaNombre: string;
  nit?: string | null;
  rol?: string | null;
  permisos?: string[];
  actual?: boolean;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private inactivityTimer?: ReturnType<typeof setTimeout>;

  constructor(private http: HttpClient) { this.programarCierre(); }

  login(correo: string, password: string): Observable<LoginResponse> {
    return this.http
      .post<LoginResponse>(`${environment.apiUrl}/auth/login`, { correo, password })
      .pipe(
        tap((res) => {
          localStorage.setItem('token', res.token);
          localStorage.setItem('rol', res.rol);
          localStorage.setItem('nombre', res.nombre);
          localStorage.setItem('permisos', JSON.stringify(res.permisos || []));
          localStorage.setItem('nivel', res.nivel || 'REGULAR');
          localStorage.setItem('empresaId', res.empresaId == null ? '' : String(res.empresaId));
          localStorage.setItem('empresaNombre', res.empresaNombre || '');
          this.guardarEmpresas(res.empresas || []);
          this.programarCierre();
        })
      );
  }

  /** Empresas del usuario (multiempresa). */
  misEmpresas(): Observable<EmpresaSesion[]> {
    return this.http.get<EmpresaSesion[]>(`${environment.apiUrl}/auth/mis-empresas`);
  }

  /**
   * Cambia de empresa: el backend devuelve un token nuevo con el rol de esa
   * empresa. Se guarda la sesion y se recarga la aplicacion para que todos los
   * datos (y el tema) se ajusten a la nueva empresa.
   */
  cambiarEmpresa(empresaId: number): Observable<LoginResponse> {
    return this.http
      .post<LoginResponse>(`${environment.apiUrl}/auth/cambiar-empresa`, { empresaId })
      .pipe(
        tap((res) => {
          localStorage.setItem('token', res.token);
          localStorage.setItem('rol', res.rol);
          localStorage.setItem('nombre', res.nombre);
          localStorage.setItem('permisos', JSON.stringify(res.permisos || []));
          localStorage.setItem('nivel', res.nivel || 'REGULAR');
          localStorage.setItem('empresaId', res.empresaId == null ? '' : String(res.empresaId));
          localStorage.setItem('empresaNombre', res.empresaNombre || '');
          this.guardarEmpresas(res.empresas || []);
          this.programarCierre();
        })
      );
  }

  /** Empresas guardadas en la sesion (para pintar el selector sin esperar). */
  getEmpresas(): EmpresaSesion[] {
    try {
      return JSON.parse(localStorage.getItem('empresas') || '[]');
    } catch {
      return [];
    }
  }

  private guardarEmpresas(empresas: EmpresaSesion[]): void {
    localStorage.setItem('empresas', JSON.stringify(empresas || []));
  }

  logout(): void {
    if (this.inactivityTimer) clearTimeout(this.inactivityTimer);
    ['token', 'rol', 'nombre', 'permisos', 'nivel', 'empresaId', 'empresaNombre', 'empresas']
      .forEach((clave) => localStorage.removeItem(clave));
  }

  registrarActividad(): void { if (this.isLoggedIn()) this.programarCierre(); }

  private programarCierre(): void {
    if (this.inactivityTimer) clearTimeout(this.inactivityTimer);
    if (!this.getToken()) return;
    this.inactivityTimer = setTimeout(() => this.logout(), 30 * 60 * 1000);
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  getName(): string { return localStorage.getItem('nombre') || 'Usuario'; }

  /** HU-12: SUPER_ADMIN (plataforma) | ADMIN (empresa) | REGULAR. */
  getNivel(): string { return (localStorage.getItem('nivel') || 'REGULAR').toUpperCase(); }

  isSuperAdmin(): boolean { return this.getNivel() === 'SUPER_ADMIN'; }

  getEmpresaId(): number | null {
    const valor = localStorage.getItem('empresaId');
    return valor ? Number(valor) : null;
  }

  getEmpresaNombre(): string { return localStorage.getItem('empresaNombre') || ''; }

  isLoggedIn(): boolean {
    const token = this.getToken();
    if (!token) return false;
    try {
      const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      if (payload.exp * 1000 <= Date.now()) { this.logout(); return false; }
      return true;
    } catch { this.logout(); return false; }
  }

  isAdmin(): boolean {
    if (this.isSuperAdmin()) return true;
    return (localStorage.getItem('rol') || '').toUpperCase() === 'ADMINISTRADOR';
  }

  hasPermission(permission: string): boolean {
    if (this.isSuperAdmin()) return true;
    return this.isAdmin() || this.getPermissions().includes(permission);
  }

  getPermissions(): string[] {
    try { return JSON.parse(localStorage.getItem('permisos') || '[]'); } catch { return []; }
  }

  /** HU-01/HU-04/HU-12: opciones de menu segun nivel, rol y permisos del token. */
  menu(): ItemMenu[] {
    return MENU.filter((item) => {
      if (item.soloSuperAdmin) return this.isSuperAdmin();
      if (item.soloAdmin) return this.isAdmin();
      return !item.permiso || this.hasPermission(item.permiso);
    });
  }

  /** Primera pantalla a la que el usuario tiene acceso (evita redirecciones en bucle). */
  rutaInicial(): string {
    if (!this.isLoggedIn()) return '/login';
    return this.menu()[0]?.ruta ?? '/login';
  }
}
