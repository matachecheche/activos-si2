import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivoService } from './activo.service';
import { Activo, ActivoRequest } from '../../core/models/activo.model';
import { Categoria } from '../../core/models/categoria.model';
import { mensajeError } from '../../core/util/http-error';

/** HU-02: formulario (modal) para registrar o editar un activo. */
@Component({
  selector: 'app-activo-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="modal-backdrop" (click)="cerrar.emit()">
      <form class="card modal ancho" (ngSubmit)="guardar()" (click)="$event.stopPropagation()">
        <div class="modal-header">
          <div><span class="eyebrow">ACTIVOS FIJOS</span><h2>{{ activo ? 'Editar activo ' + activo.codigo : 'Nuevo activo' }}</h2></div>
          <button type="button" class="close-button" (click)="cerrar.emit()">&times;</button>
        </div>
        <div *ngIf="error" class="alert-error">{{ error }}</div>
        <div class="form-grid2">
          <div class="field span-2"><label>Nombre *</label>
            <input name="nombre" [(ngModel)]="form.nombre" maxlength="150" required placeholder="Ej.: Laptop Dell Latitude 5440"></div>
          <div class="field"><label>Categoría *</label>
            <select name="categoriaId" [(ngModel)]="form.categoriaId" required>
              <option *ngFor="let c of categorias" [ngValue]="c.id">{{ c.nombre }}</option>
            </select></div>
          <div class="field"><label>Valor de adquisición (Bs) *</label>
            <input name="valor" type="number" step="0.01" min="0.01" [(ngModel)]="form.valor" required placeholder="0.00"></div>
          <div class="field"><label>Fecha de adquisición *</label>
            <input name="fechaAdquisicion" type="date" [(ngModel)]="form.fechaAdquisicion" required></div>
          <div class="field"><label>Proveedor</label>
            <input name="proveedor" [(ngModel)]="form.proveedor" maxlength="150" placeholder="Proveedor (opcional)"></div>
          <div class="field span-2"><label>Observaciones</label>
            <textarea name="observaciones" [(ngModel)]="form.observaciones" maxlength="255"></textarea></div>
          <div class="field"><label>Valor residual (Bs)</label>
            <input name="valorResidual" type="number" step="0.01" min="0" [(ngModel)]="form.valorResidual" placeholder="Según la categoría">
            <small>Opcional. Si se deja vacío se usa el porcentaje residual de la categoría.</small></div>
          <div class="field"><label>Inicio de depreciación</label>
            <input name="fechaInicioDepreciacion" type="date" [(ngModel)]="form.fechaInicioDepreciacion">
            <small>Opcional. Por defecto, la fecha de adquisición.</small></div>
        </div>
        <div class="modal-actions">
          <button type="button" class="btn-secondary" (click)="cerrar.emit()">Cancelar</button>
          <button type="submit" class="btn-primary" [disabled]="guardando">{{ guardando ? 'Guardando...' : 'Guardar activo' }}</button>
        </div>
      </form>
    </div>
  `
})
export class ActivoFormComponent implements OnInit {
  @Input() activo: Activo | null = null;
  @Input() categorias: Categoria[] = [];
  @Output() guardado = new EventEmitter<Activo>();
  @Output() cerrar = new EventEmitter<void>();

  form: ActivoRequest = { nombre: '', categoriaId: 0, valor: 0, fechaAdquisicion: '', proveedor: '', observaciones: '', valorResidual: null, fechaInicioDepreciacion: '' };
  error = '';
  guardando = false;

  constructor(private activoService: ActivoService) {}

  ngOnInit(): void {
    if (this.activo) {
      const a = this.activo;
      this.form = {
        nombre: a.nombre,
        categoriaId: a.categoriaId,
        valor: a.valor,
        fechaAdquisicion: a.fechaAdquisicion,
        proveedor: a.proveedor ?? '',
        observaciones: a.observaciones ?? '',
        valorResidual: a.valorResidual ?? null,
        fechaInicioDepreciacion: a.fechaInicioDepreciacion ?? ''
      };
    } else {
      this.form.categoriaId = this.categorias[0]?.id ?? 0;
    }
  }

  guardar(): void {
    this.error = '';
    const f = this.form;
    if (!f.nombre?.trim() || !f.categoriaId || !f.fechaAdquisicion) {
      this.error = 'Completa los campos obligatorios: nombre, categoría, valor y fecha de adquisición.';
      return;
    }
    if (!f.valor || f.valor <= 0) {
      this.error = 'El valor de adquisición no puede ser negativo ni cero.';
      return;
    }
    const payload: ActivoRequest = {
      ...f,
      nombre: f.nombre.trim(),
      proveedor: f.proveedor?.trim() || null,
      observaciones: f.observaciones?.trim() || null,
      valorResidual: f.valorResidual === null || f.valorResidual === undefined || (f.valorResidual as unknown) === '' ? null : f.valorResidual,
      fechaInicioDepreciacion: f.fechaInicioDepreciacion || null
    };
    this.guardando = true;
    const peticion = this.activo
      ? this.activoService.actualizar(this.activo.id, payload)
      : this.activoService.registrar(payload);
    peticion.subscribe({
      next: (resultado) => { this.guardando = false; this.guardado.emit(resultado); },
      error: (err) => { this.guardando = false; this.error = mensajeError(err, 'No se pudo guardar el activo.'); }
    });
  }
}
