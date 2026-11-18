import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { ActivoService } from './activo.service';
import { ActivoFormComponent } from './activo-form.component';
import { Activo, Asignacion, HistorialEstado } from '../../core/models/activo.model';
import { Categoria } from '../../core/models/categoria.model';
import { DepreciacionActivo, MantenimientoActivo, Ubicacion } from '../../core/models/sprint2.models';
import { AsignacionService, Responsable } from '../asignaciones/asignacion.service';
import { DepreciacionService } from '../depreciacion/depreciacion.service';
import { MantenimientoService } from '../mantenimientos/mantenimiento.service';
import { CategoriaService } from '../../core/services/categoria.service';
import { UbicacionService } from '../../core/services/ubicacion.service';
import { AuthService } from '../../core/auth/auth.service';
import { claseBadge, descargarBlob, etiqueta } from '../../core/util/formato';
import { mensajeError } from '../../core/util/http-error';

type Pestana = 'datos' | 'asignacion' | 'estado' | 'qr' | 'depreciacion' | 'mantenimiento';

/** Ficha del activo: datos, asignacion (HU-03), estado (HU-06), QR (HU-05), depreciacion (HU-07) y mantenimientos (HU-08). */
@Component({
  selector: 'app-activo-detalle',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, ActivoFormComponent],
  templateUrl: './activo-detalle.component.html',
  styleUrl: './activo-detalle.component.scss'
})
export class ActivoDetalleComponent implements OnInit, OnDestroy {
  activo: Activo | null = null;
  categorias: Categoria[] = [];
  pestana: Pestana = 'datos';
  editando = false;
  error = '';
  ok = '';

  // asignacion
  responsables: Responsable[] = [];
  ubicaciones: Ubicacion[] = [];
  historialAsignaciones: Asignacion[] = [];
  responsableId: number | null = null;
  ubicacionId: number | null = null;
  nuevaUbicacion = '';

  // estado
  historialEstados: HistorialEstado[] = [];
  nuevoEstado = '';
  motivo = '';

  // QR
  qrUrl: string | null = null;
  cargandoQr = false;

  // depreciacion
  depreciacion: DepreciacionActivo | null = null;
  calculando = false;

  // mantenimientos
  mantenimientos: MantenimientoActivo | null = null;

  etiqueta = etiqueta;
  claseBadge = claseBadge;

  constructor(
    private route: ActivatedRoute,
    private activoService: ActivoService,
    private asignacionService: AsignacionService,
    private ubicacionService: UbicacionService,
    private categoriaService: CategoriaService,
    private depreciacionService: DepreciacionService,
    private mantenimientoService: MantenimientoService,
    public auth: AuthService
  ) {}

  ngOnInit(): void {
    this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.liberarQr();
      this.activo = null;
      this.pestana = 'datos';
      this.cargar(id);
    });
    this.categoriaService.listar().subscribe({ next: (c) => (this.categorias = c), error: () => (this.categorias = []) });
  }

  ngOnDestroy(): void {
    this.liberarQr();
  }

  // ---- permisos ----
  get puedeEditar(): boolean { return this.auth.hasPermission('ACTIVOS_EDITAR'); }
  get puedeCrear(): boolean { return this.auth.hasPermission('ACTIVOS_CREAR'); }
  get puedeBaja(): boolean { return this.auth.hasPermission('ACTIVOS_ELIMINAR'); }
  get veDepreciacion(): boolean { return this.auth.hasPermission('DEPRECIACION_LEER'); }
  get veMantenimientos(): boolean { return this.auth.hasPermission('MANTENIMIENTO_LEER'); }

  // ---- carga ----
  cargar(id: number): void {
    this.error = '';
    this.activoService.obtener(id).subscribe({
      next: (activo) => (this.activo = activo),
      error: (err) => (this.error = mensajeError(err, 'No se pudo cargar el activo.'))
    });
  }

  recargarActivo(): void {
    if (!this.activo) return;
    this.activoService.obtener(this.activo.id).subscribe({
      next: (activo) => (this.activo = activo),
      error: (err) => (this.error = mensajeError(err))
    });
  }

  seleccionar(p: Pestana): void {
    this.pestana = p;
    this.error = '';
    this.ok = '';
    if (!this.activo) return;
    if (p === 'asignacion') this.cargarAsignacion();
    if (p === 'estado') this.cargarHistorialEstados();
    if (p === 'qr' && !this.qrUrl) this.cargarQr();
    if (p === 'depreciacion') this.cargarDepreciacion();
    if (p === 'mantenimiento') this.cargarMantenimientos();
  }

  alGuardar(activo: Activo): void {
    this.editando = false;
    this.ok = `Activo ${activo.codigo} actualizado.`;
    this.liberarQr();
    this.cargar(activo.id);
  }

  // ---- asignacion (HU-03) ----
  cargarAsignacion(): void {
    if (!this.activo) return;
    this.asignacionService.historial(this.activo.id).subscribe({
      next: (h) => (this.historialAsignaciones = h),
      error: (err) => (this.error = mensajeError(err))
    });
    if (this.puedeEditar) {
      this.asignacionService.responsables().subscribe({ next: (r) => (this.responsables = r), error: () => (this.responsables = []) });
      this.ubicacionService.listar().subscribe({ next: (u) => (this.ubicaciones = u), error: () => (this.ubicaciones = []) });
    }
  }

  get puedeAsignar(): boolean {
    return this.puedeEditar && !!this.activo && ['DISPONIBLE', 'EN_USO'].includes(this.activo.estado);
  }

  get motivoSinAsignar(): string {
    switch (this.activo?.estado) {
      case 'DADO_DE_BAJA': return 'Un activo dado de baja no puede asignarse.';
      case 'EN_MANTENIMIENTO': return 'El activo está en mantenimiento; podrá asignarse cuando finalice.';
      case 'INACTIVO': return 'El activo está inactivo; reactívalo (Disponible) para poder asignarlo.';
      default: return '';
    }
  }

  crearUbicacion(): void {
    const nombre = this.nuevaUbicacion.trim();
    if (!nombre) return;
    this.ubicacionService.crear(nombre).subscribe({
      next: (u) => { this.ubicaciones = [...this.ubicaciones, u]; this.ubicacionId = u.id; this.nuevaUbicacion = ''; },
      error: (err) => (this.error = mensajeError(err))
    });
  }

  asignar(): void {
    this.error = '';
    this.ok = '';
    if (!this.activo || !this.responsableId || !this.ubicacionId) {
      this.error = 'Selecciona el responsable y la ubicación.';
      return;
    }
    this.asignacionService.asignar({ activoId: this.activo.id, responsableId: this.responsableId, ubicacionId: this.ubicacionId }).subscribe({
      next: () => {
        this.ok = 'Activo asignado correctamente. El estado pasó a En uso.';
        this.responsableId = null;
        this.ubicacionId = null;
        this.recargarActivo();
        this.cargarAsignacion();
      },
      error: (err) => (this.error = mensajeError(err, 'No se pudo asignar el activo.'))
    });
  }

  // ---- estado (HU-06) ----
  cargarHistorialEstados(): void {
    if (!this.activo) return;
    this.activoService.historialEstados(this.activo.id).subscribe({
      next: (h) => (this.historialEstados = h),
      error: (err) => (this.error = mensajeError(err))
    });
  }

  get opcionesEstado(): string[] {
    if (!this.activo) return [];
    if (this.activo.estado === 'DADO_DE_BAJA' && !this.auth.isAdmin()) return [];
    return this.activo.estadosPermitidos.filter((e) => e !== 'DADO_DE_BAJA' || this.puedeBaja);
  }

  get ayudaEstado(): string {
    switch (this.activo?.estado) {
      case 'DADO_DE_BAJA': return this.auth.isAdmin() ? 'Solo un administrador puede reactivar un activo dado de baja.' : 'Solo un administrador puede reactivar un activo dado de baja.';
      case 'EN_MANTENIMIENTO': return 'Finaliza o cancela el mantenimiento en ejecución para cambiar el estado (solo se permite dar de baja).';
      case 'EN_USO': return 'Para dejar el activo Disponible se libera su asignación actual.';
      default: return '';
    }
  }

  cambiarEstado(): void {
    this.error = '';
    this.ok = '';
    if (!this.activo) return;
    if (!this.nuevoEstado) { this.error = 'Selecciona el nuevo estado.'; return; }
    if (!this.motivo.trim()) { this.error = 'Debes indicar el motivo del cambio de estado.'; return; }
    if (this.nuevoEstado === 'DADO_DE_BAJA' && !confirm('¿Dar de baja este activo? Dejará de depreciarse y se liberará su asignación.')) return;
    this.activoService.cambiarEstado(this.activo.id, { estado: this.nuevoEstado, motivo: this.motivo.trim() }).subscribe({
      next: (activo) => {
        this.activo = activo;
        this.ok = `Estado actualizado a ${activo.estadoEtiqueta}.`;
        this.nuevoEstado = '';
        this.motivo = '';
        this.cargarHistorialEstados();
      },
      error: (err) => (this.error = mensajeError(err, 'No se pudo cambiar el estado.'))
    });
  }

  // ---- QR (HU-05) ----
  cargarQr(): void {
    if (!this.activo) return;
    this.cargandoQr = true;
    this.activoService.qr(this.activo.id, 480).subscribe({
      next: (blob) => { this.qrUrl = URL.createObjectURL(blob); this.cargandoQr = false; },
      error: (err) => { this.cargandoQr = false; this.error = mensajeError(err, 'No se pudo generar el código QR.'); }
    });
  }

  private liberarQr(): void {
    if (this.qrUrl) URL.revokeObjectURL(this.qrUrl);
    this.qrUrl = null;
  }

  descargarPng(): void {
    if (!this.qrUrl || !this.activo) return;
    const activo = this.activo;
    const img = new Image();
    img.onload = () => {
      const lado = img.naturalWidth;
      const canvas = document.createElement('canvas');
      canvas.width = lado + 80;
      canvas.height = lado + 190;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(img, 40, 30);
      ctx.fillStyle = '#000000';
      ctx.textAlign = 'center';
      ctx.font = 'bold 34px Arial, sans-serif';
      ctx.fillText(activo.codigo, canvas.width / 2, lado + 90);
      ctx.font = '22px Arial, sans-serif';
      this.escribirLineas(ctx, activo.nombre, canvas.width / 2, lado + 125, canvas.width - 60, 28, 2);
      canvas.toBlob((blob) => { if (blob) descargarBlob(blob, `etiqueta-${activo.codigo}.png`); }, 'image/png');
    };
    img.src = this.qrUrl;
  }

  private escribirLineas(ctx: CanvasRenderingContext2D, texto: string, x: number, y: number, ancho: number, alto: number, max: number): void {
    const palabras = texto.split(/\s+/);
    let linea = '';
    let n = 0;
    for (let i = 0; i < palabras.length; i++) {
      const prueba = linea ? `${linea} ${palabras[i]}` : palabras[i];
      if (ctx.measureText(prueba).width > ancho && linea) {
        n++;
        ctx.fillText(n === max ? linea + '...' : linea, x, y);
        if (n === max) return;
        y += alto;
        linea = palabras[i];
      } else {
        linea = prueba;
      }
    }
    if (linea) ctx.fillText(linea, x, y);
  }

  descargarPdf(): void {
    if (!this.activo) return;
    const codigo = this.activo.codigo;
    this.activoService.etiquetaPdf(this.activo.id).subscribe({
      next: (blob) => descargarBlob(blob, `etiqueta-${codigo}.pdf`),
      error: (err) => (this.error = mensajeError(err, 'No se pudo generar la etiqueta PDF.'))
    });
  }

  imprimir(): void {
    if (!this.qrUrl || !this.activo) return;
    const ventana = window.open('', '_blank', 'width=420,height=620');
    if (!ventana) {
      this.error = 'El navegador bloqueó la ventana de impresión. Permite las ventanas emergentes o descarga la etiqueta PDF.';
      return;
    }
    const esc = (t: string) => t.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c] as string));
    ventana.document.write(
      `<html><head><title>Etiqueta ${esc(this.activo.codigo)}</title><style>body{font-family:Arial,sans-serif;text-align:center;margin:24px}` +
      `img{width:260px;height:260px;image-rendering:pixelated}h1{font-size:26px;margin:10px 0 4px}p{font-size:15px;margin:0}</style></head>` +
      `<body><img id="qr" src="${this.qrUrl}"><h1>${esc(this.activo.codigo)}</h1><p>${esc(this.activo.nombre)}</p>` +
      `<script>document.getElementById('qr').onload=function(){setTimeout(function(){window.print()},200)}</script></body></html>`
    );
    ventana.document.close();
  }

  // ---- depreciacion (HU-07) ----
  cargarDepreciacion(): void {
    if (!this.activo || !this.veDepreciacion) return;
    this.depreciacionService.tabla(this.activo.id).subscribe({
      next: (d) => (this.depreciacion = d),
      error: (err) => (this.error = mensajeError(err))
    });
  }

  calcularDepreciacion(): void {
    if (!this.activo) return;
    this.calculando = true;
    this.depreciacionService.calcularActivo(this.activo.id).subscribe({
      next: (r) => {
        this.calculando = false;
        this.ok = r.periodosGenerados ? `Se generaron ${r.periodosGenerados} periodo(s) pendiente(s).` : 'La depreciación ya estaba al día.';
        this.cargarDepreciacion();
      },
      error: (err) => { this.calculando = false; this.error = mensajeError(err); }
    });
  }

  // ---- mantenimientos (HU-08) ----
  cargarMantenimientos(): void {
    if (!this.activo || !this.veMantenimientos) return;
    this.mantenimientoService.porActivo(this.activo.id).subscribe({
      next: (m) => (this.mantenimientos = m),
      error: (err) => (this.error = mensajeError(err))
    });
  }
}
