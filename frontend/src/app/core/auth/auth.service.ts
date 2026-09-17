import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';

interface LoginResponse {
  token: string;
  nombre: string;
  rol: string;
  permisos: string[];
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
          this.programarCierre();
        })
      );
  }

  logout(): void {
    if (this.inactivityTimer) clearTimeout(this.inactivityTimer);
    localStorage.removeItem('token');
    localStorage.removeItem('rol');
    localStorage.removeItem('nombre');
    localStorage.removeItem('permisos');
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
    return (localStorage.getItem('rol') || '').toUpperCase() === 'ADMINISTRADOR';
  }

  hasPermission(permission: string): boolean {
    return this.isAdmin() || this.getPermissions().includes(permission);
  }

  getPermissions(): string[] {
    try { return JSON.parse(localStorage.getItem('permisos') || '[]'); } catch { return []; }
  }
}
