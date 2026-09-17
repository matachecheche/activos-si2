import { Component, OnDestroy } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';

interface UsuarioPrueba {
  rol: string;
  correo: string;
  password: string;
}

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent implements OnDestroy {
  correo = '';
  password = '';
  errorMsg = '';
  bloqueado = false;
  correoBloqueado = '';
  segundosBloqueo = 0;
  private timer?: ReturnType<typeof setInterval>;
  enviando = false;

  // Usuarios de prueba sembrados por fix.ps1 (ver database/fix_usuarios_prueba.sql).
  // Solo para pruebas del Sprint 1: quitar antes de un entorno real.
  usuariosPrueba: UsuarioPrueba[] = [
    { rol: 'ADMINISTRADOR', correo: 'admin@uagrm.edu.bo', password: 'admin123' },
    { rol: 'ENCARGADO_ACTIVOS', correo: 'encargado@uagrm.edu.bo', password: 'encargado123' },
    { rol: 'CONTADOR', correo: 'contador@uagrm.edu.bo', password: 'contador123' },
    { rol: 'RESPONSABLE_FINANCIERO', correo: 'financiero@uagrm.edu.bo', password: 'financiero123' }
  ];

  constructor(private authService: AuthService, private router: Router) {}

  usarUsuario(u: UsuarioPrueba): void {
    this.correo = u.correo;
    this.password = u.password;
    this.cambioCorreo(this.correo);
  }

  cambioCorreo(correo: string): void {
    if (this.bloqueado && correo.trim().toLowerCase() !== this.correoBloqueado) {
      this.bloqueado = false;
      this.segundosBloqueo = 0;
      this.errorMsg = '';
    }
  }

  onSubmit(): void {
    if (this.bloqueado || this.enviando) return;
    this.errorMsg = '';
    this.enviando = true;
    this.authService.login(this.correo, this.password).subscribe({
      next: () => this.router.navigate(['/activos']),
      error: (error) => {
        this.enviando = false;
        const detail = this.obtenerMensaje(error);
        this.errorMsg = detail || 'Credenciales invalidas.';
        if (error.status === 423 || /bloquead/i.test(detail)) this.iniciarCuentaRegresiva(detail);
      }
    });
  }

  private iniciarCuentaRegresiva(mensaje: string): void {
    const coincidencia = mensaje.match(/(\d+)\s*segundos?/i);
    this.segundosBloqueo = coincidencia ? Number(coincidencia[1]) : 30;
    this.correoBloqueado = this.correo.trim().toLowerCase();
    this.bloqueado = true;
    if (this.timer) clearInterval(this.timer);
    const terminaEn = Date.now() + this.segundosBloqueo * 1000;
    this.timer = setInterval(() => {
      this.segundosBloqueo = Math.ceil((terminaEn - Date.now()) / 1000);
      if (this.segundosBloqueo <= 0) {
        if (this.timer) clearInterval(this.timer);
        this.bloqueado = false;
        this.errorMsg = 'Ya puedes volver a intentarlo.';
      } else {
        this.errorMsg = `Cuenta bloqueada. Intenta nuevamente en ${this.segundosBloqueo} segundos.`;
      }
    }, 1000);
  }

  private obtenerMensaje(error: any): string {
    if (typeof error.error === 'string') return error.error;
    return error.error?.message || error.error?.detail || error.message || '';
  }

  ngOnDestroy(): void { if (this.timer) clearInterval(this.timer); }
}
