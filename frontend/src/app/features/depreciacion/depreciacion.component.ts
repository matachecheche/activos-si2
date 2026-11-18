import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { DepreciacionService } from './depreciacion.service';
import { CategoriaService } from '../../core/services/categoria.service';
import { Categoria } from '../../core/models/categoria.model';
import { DepreciacionActivo, ResumenDepreciacion } from '../../core/models/sprint2.models';
import { AuthService } from '../../core/auth/auth.service';
import { claseBadge, etiqueta } from '../../core/util/formato';
import { mensajeError } from '../../core/util/http-error';

/** HU-07: consulta de depreciacion y valor en libros, calculo pendiente y parametros por categoria. */
@Component({
  selector: 'app-depreciacion',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './depreciacion.component.html',
  styleUrl: './depreciacion.component.scss'
})
export class DepreciacionComponent implements OnInit {
  resumen: ResumenDepreciacion[] = [];
  categorias: Categoria[] = [];
  seleccionado: DepreciacionActivo | null = null;
  seleccionId: number | null = null;
  filtro = '';
  error = '';
  ok = '';
  calculando = false;

  // edicion de parametros de una categoria
  editandoCategoria: Categoria | null = null;
  formCat = { vidaUtil: null as number | null, valorResidualPct: 0 as number | null, depreciable: true, metodoDepreciacion: 'LINEA_RECTA' };
  errorCat = '';

  etiqueta = etiqueta;
  claseBadge = claseBadge;

  constructor(private depreciacionService: DepreciacionService, private categoriaService: CategoriaService, public auth: AuthService) {}

  ngOnInit(): void {
    this.cargar();
    this.cargarCategorias();
  }

  cargar(): void {
    this.depreciacionService.resumen().subscribe({
      next: (r) => (this.resumen = r),
      error: (err) => (this.error = mensajeError(err, 'No se pudo cargar la depreciación.'))
    });
  }

  cargarCategorias(): void {
    this.categoriaService.listar().subscribe({ next: (c) => (this.categorias = c), error: () => (this.categorias = []) });
  }

  get filtrados(): ResumenDepreciacion[] {
    const t = this.filtro.trim().toLowerCase();
    return this.resumen.filter((r) => !t || r.codigo.toLowerCase().includes(t) || r.nombre.toLowerCase().includes(t) || r.categoria.toLowerCase().includes(t));
  }

  get totales() {
    const dep = this.resumen.filter((r) => r.depreciable);
    const suma = (f: (r: ResumenDepreciacion) => number) => dep.reduce((acc, r) => acc + f(r), 0);
    return {
      cantidad: dep.length,
      adquisicion: suma((r) => r.valorAdquisicion),
      acumulada: suma((r) => r.depreciacionAcumulada),
      libros: suma((r) => r.valorEnLibros)
    };
  }

  ver(r: ResumenDepreciacion): void {
    this.seleccionId = r.activoId;
    this.depreciacionService.tabla(r.activoId).subscribe({
      next: (t) => (this.seleccionado = t),
      error: (err) => (this.error = mensajeError(err))
    });
  }

  calcular(): void {
    this.error = '';
    this.ok = '';
    this.calculando = true;
    this.depreciacionService.calcular().subscribe({
      next: (r) => {
        this.calculando = false;
        this.ok = r.periodosGenerados
          ? `Se generaron ${r.periodosGenerados} periodo(s) para ${r.activosProcesados} activo(s) hasta ${r.hasta}.`
          : `La depreciación de ${r.activosProcesados} activo(s) ya estaba al día hasta ${r.hasta}.`;
        this.cargar();
        if (this.seleccionId) this.depreciacionService.tabla(this.seleccionId).subscribe((t) => (this.seleccionado = t));
      },
      error: (err) => { this.calculando = false; this.error = mensajeError(err, 'No se pudo calcular la depreciación.'); }
    });
  }

  // ---- parametros por categoria ----
  get puedeParametrizar(): boolean {
    return this.auth.hasPermission('DEPRECIACION_EDITAR') || this.auth.hasPermission('ACTIVOS_EDITAR');
  }

  editarCategoria(c: Categoria): void {
    this.errorCat = '';
    this.editandoCategoria = c;
    this.formCat = {
      vidaUtil: c.vidaUtil ?? null,
      valorResidualPct: c.valorResidualPct ?? 0,
      depreciable: !!c.depreciable,
      metodoDepreciacion: c.metodoDepreciacion || 'LINEA_RECTA'
    };
  }

  guardarCategoria(): void {
    if (!this.editandoCategoria) return;
    this.errorCat = '';
    if (this.formCat.depreciable && (!this.formCat.vidaUtil || this.formCat.vidaUtil < 1)) {
      this.errorCat = 'Indica la vida útil (en años) de una categoría depreciable.';
      return;
    }
    this.categoriaService.actualizar(this.editandoCategoria.id, {
      nombre: this.editandoCategoria.nombre,
      depreciable: this.formCat.depreciable,
      vidaUtil: this.formCat.depreciable ? this.formCat.vidaUtil : null,
      valorResidualPct: this.formCat.valorResidualPct ?? 0,
      metodoDepreciacion: this.formCat.metodoDepreciacion
    }).subscribe({
      next: () => {
        this.editandoCategoria = null;
        this.ok = 'Parámetros actualizados. La depreciación de la categoría se recalculó.';
        this.cargarCategorias();
        this.cargar();
        this.seleccionado = null;
        this.seleccionId = null;
      },
      error: (err) => (this.errorCat = mensajeError(err, 'No se pudieron guardar los parámetros.'))
    });
  }
}
