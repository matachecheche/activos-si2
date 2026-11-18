import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { PresupuestoService } from './presupuesto.service';
import { Area, Presupuesto } from '../../core/models/sprint2.models';
import { AuthService } from '../../core/auth/auth.service';
import { claseBadge, etiqueta, gestionActual } from '../../core/util/formato';
import { mensajeError } from '../../core/util/http-error';

/** HU-09: presupuestos por gestion y area. */
@Component({
  selector: 'app-presupuestos',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './presupuestos.component.html',
  styleUrl: './presupuestos.component.scss'
})
export class PresupuestosComponent implements OnInit {
  presupuestos: Presupuesto[] = [];
  areas: Area[] = [];
  filtroGestion: number | null = null;
  filtroArea: number | null = null;
  error = '';
  ok = '';

  formAbierto = false;
  errorForm = '';
  form = { areaId: null as number | null, gestion: gestionActual(), montoAprobado: null as number | null };
  nuevaArea = '';

  etiqueta = etiqueta;
  claseBadge = claseBadge;

  constructor(private presupuestoService: PresupuestoService, public auth: AuthService) {}

  ngOnInit(): void {
    this.cargar();
    this.cargarAreas();
  }

  cargarAreas(): void {
    this.presupuestoService.areas().subscribe({ next: (a) => (this.areas = a.filter((x) => x.activo)), error: () => (this.areas = []) });
  }

  cargar(): void {
    this.presupuestoService.listar(this.filtroGestion, this.filtroArea).subscribe({
      next: (p) => (this.presupuestos = p),
      error: (err) => (this.error = mensajeError(err, 'No se pudieron cargar los presupuestos.'))
    });
  }

  limpiarFiltros(): void {
    this.filtroGestion = null;
    this.filtroArea = null;
    this.cargar();
  }

  nuevo(): void {
    this.errorForm = '';
    this.form = { areaId: this.areas[0]?.id ?? null, gestion: gestionActual(), montoAprobado: null };
    this.formAbierto = true;
  }

  crearArea(): void {
    const nombre = this.nuevaArea.trim();
    if (!nombre) return;
    this.presupuestoService.crearArea(nombre).subscribe({
      next: (a) => { this.areas = [...this.areas, a]; this.form.areaId = a.id; this.nuevaArea = ''; },
      error: (err) => (this.errorForm = mensajeError(err))
    });
  }

  guardar(): void {
    this.errorForm = '';
    if (!this.form.areaId || !this.form.gestion || !this.form.montoAprobado || this.form.montoAprobado <= 0) {
      this.errorForm = 'Completa el área, la gestión y un monto aprobado mayor a cero.';
      return;
    }
    this.presupuestoService.crear({ areaId: this.form.areaId, gestion: this.form.gestion, montoAprobado: this.form.montoAprobado }).subscribe({
      next: () => { this.formAbierto = false; this.ok = 'Presupuesto creado en estado Borrador. Agrega sus partidas y apruébalo.'; this.cargar(); },
      error: (err) => (this.errorForm = mensajeError(err, 'No se pudo crear el presupuesto.'))
    });
  }

  eliminar(p: Presupuesto): void {
    if (!confirm(`¿Eliminar el borrador de ${p.areaNombre} ${p.gestion}?`)) return;
    this.presupuestoService.eliminar(p.id).subscribe({
      next: () => { this.ok = 'Presupuesto eliminado.'; this.cargar(); },
      error: (err) => (this.error = mensajeError(err))
    });
  }

  claseProgreso(pct: number): string {
    return pct >= 100 ? 'progreso lleno' : pct >= 80 ? 'progreso alto' : 'progreso';
  }
}
