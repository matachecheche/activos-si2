import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RolService, Rol, Permiso } from '../../services/rol.service';
import { mensajeError } from '../../core/util/http-error';

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
  rolActual: Rol = { nombre: '', descripcion: '', permisos: [] };
  modalAbierto = false;
  mensaje = '';
  ok = '';
  errorModal = '';
  permisoModal = false;
  permisoActual: Omit<Permiso, 'id'> & { id?: number } = { modulo: '', accion: '', descripcion: '' };

  constructor(private rolService: RolService) {}
  ngOnInit(): void { this.cargar(); }

  cargar(): void {
    this.rolService.listar().subscribe({ next: roles => this.roles = roles, error: err => this.mensaje = mensajeError(err, 'No se pudieron cargar los roles.') });
    this.rolService.permisos().subscribe({ next: permisos => this.permisos = permisos, error: err => this.mensaje = mensajeError(err, 'No se pudieron cargar los permisos.') });
  }

  esAdministrador(rol: Rol): boolean { return rol.nombre === 'ADMINISTRADOR'; }

  cerrarPermisoDesdeBackdrop(evento: MouseEvent): void {
    if (evento.target === evento.currentTarget) { this.permisoModal = false; }
  }

  cerrarRolDesdeBackdrop(evento: MouseEvent): void {
    if (evento.target === evento.currentTarget) { this.modalAbierto = false; }
  }

  nuevo(): void { this.rolActual = { nombre: '', descripcion: '', permisos: [], activo: true }; this.modalAbierto = true; this.mensaje = ''; this.ok = ''; this.errorModal = ''; }
  editar(rol: Rol): void {
    this.rolActual = { id: rol.id, nombre: rol.nombre, descripcion: rol.descripcion ?? '', activo: rol.activo, permisos: [...rol.permisos] };
    this.modalAbierto = true; this.mensaje = ''; this.ok = ''; this.errorModal = '';
  }
  tienePermiso(permiso: Permiso): boolean { return this.rolActual.permisos.some(actual => actual.id === permiso.id); }
  alternar(permiso: Permiso): void {
    this.rolActual.permisos = this.tienePermiso(permiso)
      ? this.rolActual.permisos.filter(actual => actual.id !== permiso.id)
      : [...this.rolActual.permisos, permiso];
  }

  guardar(): void {
    const nombre = this.rolActual.nombre.trim();
    if (!nombre) { this.errorModal = 'El nombre del rol es obligatorio.'; return; }
    const payload = {
      nombre,
      descripcion: this.rolActual.descripcion?.trim() || null,
      permisos: this.rolActual.permisos.map(permiso => permiso.id),
      activo: this.rolActual.activo
    };
    const request = this.rolActual.id ? this.rolService.actualizar(this.rolActual.id, payload) : this.rolService.crear(payload);
    request.subscribe({
      next: () => { this.modalAbierto = false; this.ok = 'Rol guardado. Los permisos nuevos se aplican a cada usuario en su siguiente inicio de sesión.'; this.cargar(); },
      error: err => this.errorModal = mensajeError(err, 'No se pudo guardar el rol.')
    });
  }

  /** CP-02: el backend rechaza desactivar un rol con usuarios activos asignados. */
  desactivar(rol: Rol): void {
    if (!rol.id || !confirm(`¿Desactivar el rol ${rol.nombre}?`)) return;
    this.mensaje = ''; this.ok = '';
    this.rolService.desactivar(rol.id).subscribe({
      next: () => { this.ok = `Rol ${rol.nombre} desactivado.`; this.cargar(); },
      error: err => this.mensaje = mensajeError(err, 'No se pudo desactivar el rol.')
    });
  }

  reactivar(rol: Rol): void {
    if (!rol.id) return;
    this.mensaje = ''; this.ok = '';
    this.rolService.actualizar(rol.id, {
      nombre: rol.nombre, descripcion: rol.descripcion ?? null, permisos: rol.permisos.map(p => p.id), activo: true
    }).subscribe({
      next: () => { this.ok = `Rol ${rol.nombre} reactivado.`; this.cargar(); },
      error: err => this.mensaje = mensajeError(err, 'No se pudo reactivar el rol.')
    });
  }

  porModulo(modulo: string): Permiso[] { return this.permisos.filter(permiso => permiso.modulo === modulo); }
  modulos(): string[] { return [...new Set(this.permisos.map(permiso => permiso.modulo))]; }
  nuevoPermiso(): void { this.permisoActual = { modulo: '', accion: '', descripcion: '' }; this.permisoModal = true; this.mensaje = ''; }
  editarPermiso(permiso: Permiso): void { this.permisoActual = { ...permiso }; this.permisoModal = true; this.mensaje = ''; }
  guardarPermiso(): void {
    const payload = { modulo: this.permisoActual.modulo.trim(), accion: this.permisoActual.accion.trim(), descripcion: this.permisoActual.descripcion.trim() };
    if (!payload.modulo || !payload.accion || !payload.descripcion) { this.mensaje = 'Completa módulo, acción y descripción.'; return; }
    const request = this.permisoActual.id ? this.rolService.actualizarPermiso(this.permisoActual.id, payload) : this.rolService.crearPermiso(payload);
    request.subscribe({ next: () => { this.permisoModal = false; this.cargar(); }, error: err => this.mensaje = mensajeError(err, 'No se pudo guardar el permiso.') });
  }
  eliminarPermiso(permiso: Permiso): void {
    if (!confirm(`¿Eliminar el permiso ${permiso.modulo} / ${permiso.accion}?`)) return;
    this.rolService.eliminarPermiso(permiso.id).subscribe({ next: () => this.cargar(), error: err => this.mensaje = mensajeError(err, 'No se pudo eliminar el permiso.') });
  }
}
