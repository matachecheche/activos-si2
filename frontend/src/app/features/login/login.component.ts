import { Component } from '@angular/core';
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
export class LoginComponent {
  correo = '';
  password = '';
  errorMsg = '';

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
  }

  onSubmit(): void {
    this.errorMsg = '';
    this.authService.login(this.correo, this.password).subscribe({
      next: () => this.router.navigate(['/activos']),
      error: () => (this.errorMsg = 'Credenciales invalidas o cuenta bloqueada')
    });
  }
}
