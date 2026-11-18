import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MantenimientoService } from './mantenimiento.service';
import { ActivoService } from '../activos/activo.service';
import { Activo } from '../../core/models/activo.model';
import { AlertasMantenimiento, Mantenimiento, TipoMantenimiento } from '../../core/models/sprint2.models';
import { AuthService } from '../../core/auth/auth.service';
import { claseBadge, etiqueta, hoyISO } from '../../core/util/formato';
import { mensajeError } from '../../core/util/http-error';

/** HU-08: programacion, ejecucion, cierre y cancelacion de mantenimientos con alertas de vencimiento. */
@Component({
  selector: 'app-mantenimientos',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './mantenimientos.component.html',
  styleUrl: './mantenimientos.component.scss'
})
export class MantenimientosComponent implements OnInit {
  items: Mantenimiento[] = [];
  alertas: AlertasMantenimiento = { proximos: [], vencidos: [] };
  activos: Activo[] = [];

  filtroEstado = '';
  filtroTexto = '';
  error = '';
  ok = '';

  // formulario programar / reprogramar
  formAbierto = false;
  editandoId: number | null = null;
  form = this.formVacio();

  // finalizar
  finalizando: Mantenimiento | null = null;
  fin = { fechaRealizada: hoyISO(), costo: null as number | null, tecnico: '', observaciones: '' };

  // cancelar
  cancelando: Mantenimiento | null = null;
  motivoCancelacion = '';

  etiqueta = etiqueta;
  claseBadge = claseBadge;

  constructor(
    private mantenimientoService: MantenimientoService,
    private activoService: ActivoService,
    private route: ActivatedRoute,
    public auth: AuthService
  ) {}

  ngOnInit(): void {
    this.cargar();
    this.activoService.listar().subscribe({
      next: (a) => {
        this.activos = a.filter((x) => x.estado !== 'DADO_DE_BAJA');
        const preseleccion = Number(this.route.snapshot.queryParamMap.get('activoId'));
        if (preseleccion && this.auth.hasPermission('MANTENIMIENTO_CREAR')) this.nuevo(preseleccion);
      },
      error: () => (this.activos = [])
    });
  }

  cargar(): void {
    this.mantenimientoService.listar().subscribe({
      next: (m) => (this.items = m),
      error: (err) => (this.error = mensajeError(err, 'No se pudieron cargar los mantenimientos.'))
    });
    this.mantenimientoService.alertas().subscribe({ next: (a) => (this.alertas = a), error: () => undefined });
  }

  get filtrados(): Mantenimiento[] {
    const t = this.filtroTexto.trim().toLowerCase();
    return this.items.filter((m) =>
      (!this.filtroEstado || m.estado === this.filtroEstado)
      && (!t || m.activoCodigo.toLowerCase().includes(t) || m.activoNombre.toLowerCase().includes(t)));
  }

  private formVacio() {
    return { activoId: null as number | null, tipo: 'PREVENTIVO' as TipoMantenimiento, fechaProgramada: '', periodicidadDias: null as number | null, descripcion: '' };
  }

  // ---- programar ----
  nuevo(activoId?: number): void {
    this.editandoId = null;
    this.form = { ...this.formVacio(), activoId: activoId ?? null, fechaProgramada: hoyISO() };
    this.error = '';
    this.formAbierto = true;
  }

  editar(m: Mantenimiento): void {
    this.editandoId = m.id;
    this.form = {
      activoId: m.activoId,
      tipo: m.tipo,
      fechaProgramada: m.fechaProgramada ?? '',
      periodicidadDias: m.periodicidadDias ?? null,
      descripcion: m.descripcion ?? ''
    };
    this.error = '';
    this.formAbierto = true;
  }

  guardar(): void {
    this.error = '';
    const f = this.form;
    if (!f.activoId) { this.error = 'Selecciona el activo.'; return; }
    if (f.tipo === 'PREVENTIVO' && !f.fechaProgramada) { this.error = 'Indica la fecha programada del mantenimiento preventivo.'; return; }
    if (f.tipo === 'CORRECTIVO' && !f.descripcion.trim()) { this.error = 'Describe la falla del mantenimiento correctivo.'; return; }
    const payload = {
      activoId: f.activoId,
      tipo: f.tipo,
      descripcion: f.descripcion.trim() || null,
      fechaProgramada: f.fechaProgramada || null,
      periodicidadDias: f.tipo === 'PREVENTIVO' ? (f.periodicidadDias || null) : null
    };
    const peticion = this.editandoId
      ? this.mantenimientoService.actualizar(this.editandoId, payload)
      : this.mantenimientoService.programar(payload);
    peticion.subscribe({
      next: () => { this.formAbierto = false; this.ok = 'Mantenimiento guardado.'; this.cargar(); },
      error: (err) => (this.error = mensajeError(err, 'No se pudo guardar el mantenimiento.'))
    });
  }

  // ---- iniciar / finalizar / cancelar ----
  iniciar(m: Mantenimiento): void {
    this.limpiar();
    this.mantenimientoService.iniciar(m.id).subscribe({
      next: () => { this.ok = `Mantenimiento iniciado: ${m.activoCodigo} pasó a «En mantenimiento».`; this.cargar(); },
      error: (err) => (this.error = mensajeError(err, 'No se pudo iniciar el mantenimiento.'))
    });
  }

  abrirFinalizar(m: Mantenimiento): void {
    this.limpiar();
    this.finalizando = m;
    this.fin = { fechaRealizada: hoyISO(), costo: null, tecnico: m.tecnico ?? '', observaciones: '' };
  }

  finalizar(): void {
    if (!this.finalizando) return;
    this.error = '';
    if (this.fin.costo === null || this.fin.costo < 0 || !this.fin.tecnico.trim()) {
      this.error = 'Indica el costo (0 o más) y el técnico responsable.';
      return;
    }
    const codigo = this.finalizando.activoCodigo;
    this.mantenimientoService.finalizar(this.finalizando.id, {
      fechaRealizada: this.fin.fechaRealizada || null,
      costo: this.fin.costo,
      tecnico: this.fin.tecnico.trim(),
      observaciones: this.fin.observaciones.trim() || null
    }).subscribe({
      next: () => { this.finalizando = null; this.ok = `Mantenimiento finalizado: ${codigo} volvió a su estado previo.`; this.cargar(); },
      error: (err) => (this.error = mensajeError(err, 'No se pudo finalizar el mantenimiento.'))
    });
  }

  abrirCancelar(m: Mantenimiento): void {
    this.limpiar();
    this.cancelando = m;
    this.motivoCancelacion = '';
  }

  cancelar(): void {
    if (!this.cancelando) return;
    this.mantenimientoService.cancelar(this.cancelando.id, this.motivoCancelacion.trim()).subscribe({
      next: () => { this.cancelando = null; this.ok = 'Mantenimiento cancelado.'; this.cargar(); },
      error: (err) => (this.error = mensajeError(err, 'No se pudo cancelar el mantenimiento.'))
    });
  }

  private limpiar(): void { this.error = ''; this.ok = ''; }

  textoDias(m: Mantenimiento): string {
    if (m.diasParaVencer == null) return '';
    if (m.diasParaVencer < 0) return `vencido hace ${-m.diasParaVencer} día(s)`;
    if (m.diasParaVencer === 0) return 'vence hoy';
    return `en ${m.diasParaVencer} día(s)`;
  }
}
