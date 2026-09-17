import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { UsuarioService, Usuario } from '../../services/usuario.service';
import { AuthService } from '../../core/auth/auth.service';

@Component({
  selector: 'app-usuarios',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: '../usuarios.component.html',
  styleUrl: '../usuarios.component.scss'
})
export class UsuariosComponent implements OnInit {
  usuarios: Usuario[] = [];
  cargando: boolean = false;
  mensajeError: string = '';
  
  modalAbierto: boolean = false;
  modoEdicion: boolean = false;

  usuarioActual: Usuario = {
    nombre: '',
    correo: '',
    rol: 'ENCARGADO_ACTIVOS',
    password: ''
  };

  constructor(private usuarioService: UsuarioService, public authService: AuthService) {}

  ngOnInit(): void {
    this.cargarUsuarios();
  }

  cargarUsuarios(): void {
    this.cargando = true;
    this.usuarioService.getUsuarios().subscribe({
      next: (data) => {
        this.usuarios = data;
        this.cargando = false;
      },
      error: (err) => {
        this.mensajeError = 'Error al obtener usuarios. Verifique sus permisos de administrador.';
        this.cargando = false;
      }
    });
  }

  abrirModalCrear(): void {
    this.modoEdicion = false;
    this.usuarioActual = { nombre: '', correo: '', rol: 'ENCARGADO_ACTIVOS', password: '' };
    this.modalAbierto = true;
  }

  abrirModalEditar(usuario: Usuario): void {
    this.modoEdicion = true;
    this.usuarioActual = { ...usuario, password: '' };
    this.modalAbierto = true;
  }

  guardarUsuario(): void {
    const password = this.usuarioActual.password || '';
    if ((!this.modoEdicion || password) && !this.esPasswordSegura(password)) {
      this.mensajeError = 'La contraseña debe tener mínimo 8 caracteres, mayúscula, minúscula, número y carácter especial.';
      return;
    }
    this.mensajeError = '';
    if (this.modoEdicion && this.usuarioActual.id) {
      this.usuarioService.actualizarUsuario(this.usuarioActual.id, {
        nombre: this.usuarioActual.nombre,
        correo: this.usuarioActual.correo,
        rol: this.usuarioActual.rol
      }).subscribe({
        next: () => {
          this.cargarUsuarios();
          this.modalAbierto = false;
        },
        error: (err) => this.mensajeError = err.error?.detail || 'Error al actualizar usuario'
      });
    } else {
      this.usuarioService.crearUsuario(this.usuarioActual).subscribe({
        next: () => {
          this.cargarUsuarios();
          this.modalAbierto = false;
        },
        error: (err) => this.mensajeError = err.error?.detail || 'Error al crear usuario'
      });
    }
  }

  eliminarUsuario(id?: number): void {
    if (!id) return;
    if (confirm('¿Está seguro de que desea eliminar este usuario?')) {
      this.usuarioService.eliminarUsuario(id).subscribe({
        next: () => this.cargarUsuarios(),
        error: (err) => this.mensajeError = err.error?.detail || 'Error al eliminar usuario'
      });
    }
  }

  private esPasswordSegura(password: string): boolean {
    return /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z\d]).{8,}$/.test(password);
  }
}