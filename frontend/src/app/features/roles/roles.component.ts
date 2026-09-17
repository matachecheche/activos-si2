import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RolService, Rol, Permiso } from '../../services/rol.service';

@Component({
  selector: 'app-roles',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './roles.component.html',
  styleUrl: './roles.component.scss'
})
export class RolesComponent implements OnInit {
  roles: Rol[] = [];
  permisos: Permiso[] = [];
  rolActual: Rol = { nombre: '', permisos: [] };
  modalAbierto = false;
  mensaje = '';
  permisoModal = false;
  permisoActual: Omit<Permiso, 'id'> & { id?: number } = { modulo: '', accion: '', descripcion: '' };

  constructor(private rolService: RolService) {}
  ngOnInit(): void { this.cargar(); }
  cargar(): void {
    this.rolService.listar().subscribe({ next: roles => this.roles = roles, error: () => this.mensaje = 'No se pudieron cargar los roles.' });
    this.rolService.permisos().subscribe({ next: permisos => this.permisos = permisos, error: () => this.mensaje = 'No se pudieron cargar los permisos.' });
  }
  nuevo(): void { this.rolActual = { nombre: '', permisos: [] }; this.modalAbierto = true; this.mensaje = ''; }
  editar(rol: Rol): void { this.rolActual = { id: rol.id, nombre: rol.nombre, permisos: [...rol.permisos] }; this.modalAbierto = true; this.mensaje = ''; }
  tienePermiso(permiso: Permiso): boolean { return this.rolActual.permisos.some(actual => actual.id === permiso.id); }
  alternar(permiso: Permiso): void {
    this.rolActual.permisos = this.tienePermiso(permiso)
      ? this.rolActual.permisos.filter(actual => actual.id !== permiso.id)
      : [...this.rolActual.permisos, permiso];
  }
  guardar(): void {
    const payload = { nombre: this.rolActual.nombre.trim(), permisos: this.rolActual.permisos.map(permiso => permiso.id) };
    if (!payload.nombre) { this.mensaje = 'El nombre del rol es obligatorio.'; return; }
    const request = this.rolActual.id ? this.rolService.actualizar(this.rolActual.id, payload) : this.rolService.crear(payload);
    request.subscribe({ next: () => { this.modalAbierto = false; this.cargar(); }, error: err => this.mensaje = err.error?.detail || 'No se pudo guardar el rol.' });
  }
  porModulo(modulo: string): Permiso[] { return this.permisos.filter(permiso => permiso.modulo === modulo); }
  modulos(): string[] { return [...new Set(this.permisos.map(permiso => permiso.modulo))]; }
  nuevoPermiso(): void { this.permisoActual = { modulo: '', accion: '', descripcion: '' }; this.permisoModal = true; this.mensaje = ''; }
  editarPermiso(permiso: Permiso): void { this.permisoActual = { ...permiso }; this.permisoModal = true; this.mensaje = ''; }
  guardarPermiso(): void {
    const payload = { modulo: this.permisoActual.modulo.trim(), accion: this.permisoActual.accion.trim(), descripcion: this.permisoActual.descripcion.trim() };
    if (!payload.modulo || !payload.accion || !payload.descripcion) { this.mensaje = 'Completa módulo, acción y descripción.'; return; }
    const request = this.permisoActual.id ? this.rolService.actualizarPermiso(this.permisoActual.id, payload) : this.rolService.crearPermiso(payload);
    request.subscribe({ next: () => { this.permisoModal = false; this.cargar(); }, error: err => this.mensaje = err.error?.detail || 'No se pudo guardar el permiso.' });
  }
  eliminarPermiso(permiso: Permiso): void {
    if (!confirm(`¿Eliminar el permiso ${permiso.modulo} / ${permiso.accion}?`)) return;
    this.rolService.eliminarPermiso(permiso.id).subscribe({ next: () => this.cargar(), error: err => this.mensaje = err.error?.detail || 'No se pudo eliminar el permiso.' });
  }
}
