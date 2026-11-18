import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { PresupuestoService } from './presupuesto.service';
import { ActivoService } from '../activos/activo.service';
import { Activo } from '../../core/models/activo.model';
import { Ejecucion, Partida, Presupuesto } from '../../core/models/sprint2.models';
import { AuthService } from '../../core/auth/auth.service';
import { claseBadge, etiqueta, hoyISO } from '../../core/util/formato';
import { mensajeError } from '../../core/util/http-error';

type Pestana = 'partidas' | 'ejecucion';

/** HU-09 (partidas, aprobacion, cierre) y HU-10 (ejecucion y seguimiento) de un presupuesto. */
@Component({
  selector: 'app-presupuesto-detalle',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './presupuesto-detalle.component.html',
  styleUrl: './presupuesto-detalle.component.scss'
})
export class PresupuestoDetalleComponent implements OnInit {
  presupuesto: Presupuesto | null = null;
  partidas: Partida[] = [];
  ejecuciones: Ejecucion[] = [];
  activos: Activo[] = [];
  pestana: Pestana = 'partidas';
  error = '';
  ok = '';

  // partidas
  partidaAbierta = false;
  partidaEditando: Partida | null = null;
  formPartida = { codigo: '', nombre: '', montoPlanificado: null as number | null };
  errorPartida = '';

  // monto aprobado
  editandoMonto = false;
  nuevoMonto: number | null = null;

  // ejecucion
  formEjec = this.ejecVacia();
  errorEjec = '';

  etiqueta = etiqueta;
  claseBadge = claseBadge;

  constructor(
    private route: ActivatedRoute,
    private presupuestoService: PresupuestoService,
    private activoService: ActivoService,
    public auth: AuthService
  ) {}

  private get id(): number { return Number(this.route.snapshot.paramMap.get('id')); }

  ngOnInit(): void {
    this.cargar();
    if (this.auth.hasPermission('ACTIVOS_LEER')) {
      this.activoService.listar().subscribe({ next: (a) => (this.activos = a), error: () => (this.activos = []) });
    }
  }

  private ejecVacia() {
    return { partidaId: null as number | null, tipo: 'EJECUCION' as 'COMPROMISO' | 'EJECUCION', fecha: hoyISO(), concepto: '', monto: null as number | null, activoId: null as number | null, compromisoId: null as number | null };
  }

  cargar(): void {
    this.presupuestoService.seguimiento(this.id).subscribe({
      next: (s) => { this.presupuesto = s.presupuesto; this.partidas = s.partidas; },
      error: (err) => (this.error = mensajeError(err, 'No se pudo cargar el presupuesto.'))
    });
    this.presupuestoService.ejecuciones(this.id).subscribe({ next: (e) => (this.ejecuciones = e), error: () => (this.ejecuciones = []) });
  }

  get esBorrador(): boolean { return this.presupuesto?.estado === 'BORRADOR'; }
  get esAprobado(): boolean { return this.presupuesto?.estado === 'APROBADO'; }

  claseProgreso(pct: number): string {
    return pct >= 100 ? 'progreso lleno' : pct >= 80 ? 'progreso alto' : 'progreso';
  }

  // ---- presupuesto ----
  aprobar(): void {
    if (!this.presupuesto || !confirm('¿Aprobar el presupuesto? Después no podrá modificarse.')) return;
    this.limpiar();
    this.presupuestoService.aprobar(this.presupuesto.id).subscribe({
      next: () => { this.ok = 'Presupuesto aprobado. Ya se pueden registrar compromisos y ejecuciones.'; this.cargar(); },
      error: (err) => (this.error = mensajeError(err))
    });
  }

  cerrar(): void {
    if (!this.presupuesto || !confirm('¿Cerrar el presupuesto al finalizar la gestión? Ya no admitirá operaciones.')) return;
    this.limpiar();
    this.presupuestoService.cerrar(this.presupuesto.id).subscribe({
      next: () => { this.ok = 'Presupuesto cerrado.'; this.cargar(); },
      error: (err) => (this.error = mensajeError(err))
    });
  }

  abrirMonto(): void {
    this.nuevoMonto = this.presupuesto?.montoAprobado ?? null;
    this.editandoMonto = true;
    this.errorPartida = '';
  }

  guardarMonto(): void {
    if (!this.presupuesto || !this.nuevoMonto || this.nuevoMonto <= 0) { this.errorPartida = 'Indica un monto mayor a cero.'; return; }
    this.presupuestoService.actualizar(this.presupuesto.id, {
      areaId: this.presupuesto.areaId, gestion: this.presupuesto.gestion, montoAprobado: this.nuevoMonto
    }).subscribe({
      next: () => { this.editandoMonto = false; this.ok = 'Monto aprobado actualizado.'; this.cargar(); },
      error: (err) => (this.errorPartida = mensajeError(err))
    });
  }

  // ---- partidas ----
  nuevaPartida(): void {
    this.partidaEditando = null;
    this.formPartida = { codigo: '', nombre: '', montoPlanificado: null };
    this.errorPartida = '';
    this.partidaAbierta = true;
  }

  editarPartida(p: Partida): void {
    this.partidaEditando = p;
    this.formPartida = { codigo: p.codigo, nombre: p.nombre, montoPlanificado: p.montoPlanificado };
    this.errorPartida = '';
    this.partidaAbierta = true;
  }

  guardarPartida(): void {
    if (!this.presupuesto) return;
    const f = this.formPartida;
    if (!f.codigo.trim() || !f.nombre.trim() || !f.montoPlanificado || f.montoPlanificado <= 0) {
      this.errorPartida = 'Completa el código, el nombre y un monto planificado mayor a cero.';
      return;
    }
    const payload = { codigo: f.codigo.trim(), nombre: f.nombre.trim(), montoPlanificado: f.montoPlanificado };
    const peticion = this.partidaEditando
      ? this.presupuestoService.actualizarPartida(this.presupuesto.id, this.partidaEditando.id, payload)
      : this.presupuestoService.crearPartida(this.presupuesto.id, payload);
    peticion.subscribe({
      next: () => { this.partidaAbierta = false; this.ok = 'Partida guardada.'; this.cargar(); },
      error: (err) => (this.errorPartida = mensajeError(err, 'No se pudo guardar la partida.'))
    });
  }

  eliminarPartida(p: Partida): void {
    if (!this.presupuesto || !confirm(`¿Eliminar la partida ${p.codigo}?`)) return;
    this.limpiar();
    this.presupuestoService.eliminarPartida(this.presupuesto.id, p.id).subscribe({
      next: () => { this.ok = 'Partida eliminada.'; this.cargar(); },
      error: (err) => (this.error = mensajeError(err))
    });
  }

  // ---- ejecucion (HU-10) ----
  get partidaSeleccionada(): Partida | undefined {
    return this.partidas.find((p) => p.id === this.formEjec.partidaId);
  }

  /** Compromisos de la partida elegida que todavia no fueron ejecutados. */
  get compromisosPendientes(): Ejecucion[] {
    return this.ejecuciones.filter((e) => e.tipo === 'COMPROMISO' && !e.liberado && e.partidaId === this.formEjec.partidaId);
  }

  alCambiarTipo(): void {
    if (this.formEjec.tipo === 'COMPROMISO') this.formEjec.compromisoId = null;
  }

  alElegirCompromiso(): void {
    const c = this.compromisosPendientes.find((x) => x.id === this.formEjec.compromisoId);
    if (c) {
      if (!this.formEjec.monto) this.formEjec.monto = c.monto;
      if (!this.formEjec.concepto) this.formEjec.concepto = c.concepto;
    }
  }

  registrarEjecucion(): void {
    this.errorEjec = '';
    this.ok = '';
    const f = this.formEjec;
    if (!f.partidaId || !f.fecha || !f.concepto.trim() || !f.monto || f.monto <= 0) {
      this.errorEjec = 'Completa la partida, la fecha, el concepto y un monto mayor a cero.';
      return;
    }
    this.presupuestoService.registrarEjecucion({
      partidaId: f.partidaId,
      tipo: f.tipo,
      fecha: f.fecha,
      concepto: f.concepto.trim(),
      monto: f.monto,
      activoId: f.activoId || null,
      compromisoId: f.tipo === 'EJECUCION' ? (f.compromisoId || null) : null
    }).subscribe({
      next: () => {
        this.ok = f.tipo === 'COMPROMISO' ? 'Compromiso registrado.' : 'Ejecución registrada.';
        this.formEjec = this.ejecVacia();
        this.cargar();
      },
      error: (err) => (this.errorEjec = mensajeError(err, 'No se pudo registrar la operación.'))
    });
  }

  private limpiar(): void { this.error = ''; this.ok = ''; }
}
