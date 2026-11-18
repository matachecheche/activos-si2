import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ReportesService } from './reportes.service';
import { ConsultaEspec, FiltroEspec, OrdenEspec, ResultadoConsulta } from '../../core/models/sprint3.models';
import { descargarBinario } from '../../core/util/descarga';
import { environment } from '../../../environments/environment';

interface ColumnaCatalogo { nombre: string; tipo: string; etiqueta: string; }
interface TablaCatalogo { tabla: string; etiqueta: string; descripcion: string; columnas: ColumnaCatalogo[]; }
interface FiltroUi { campo: string; operador: string; valor: string; valorHasta: string; valores: string; }
interface ConsultaGuardada { id: number; nombre: string; entidad: string; definicion: string; }

@Component({
  selector: 'app-reportes',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './reportes.component.html',
  styleUrl: './reportes.component.scss'
})
export class ReportesComponent implements OnInit {
  readonly operadores = ['=', '!=', '>', '>=', '<', '<=', 'LIKE', 'NOT LIKE', 'IN', 'BETWEEN', 'IS NULL', 'IS NOT NULL'];
  readonly funciones = ['COUNT', 'SUM', 'AVG', 'MIN', 'MAX'];

  catalogo: TablaCatalogo[] = [];
  entidad = 'activo';
  columnasSeleccionadas: string[] = [];
  filtros: FiltroUi[] = [];
  ordenCampo = '';
  ordenDireccion: 'ASC' | 'DESC' = 'ASC';
  limite = 100;
  agregacionFuncion = '';
  agregacionCampo = '*';
  agruparPor: string[] = [];

  resultado: ResultadoConsulta | null = null;
  ejecutando = false;
  errorMsg = '';
  guardadas: ConsultaGuardada[] = [];
  nombreConsulta = '';

  constructor(private reportes: ReportesService) {}

  ngOnInit(): void {
    this.reportes.catalogo().subscribe({
      next: (catalogo) => {
        this.catalogo = catalogo as TablaCatalogo[];
        this.cargarEntidad(this.entidad);
      },
      error: () => (this.errorMsg = 'No se pudo cargar el catálogo de consultas.')
    });
    this.cargarGuardadas();
  }

  get tablaActual(): TablaCatalogo | undefined {
    return this.catalogo.find((t) => t.tabla === this.entidad);
  }

  cargarEntidad(tabla: string): void {
    this.entidad = tabla;
    this.columnasSeleccionadas = (this.tablaActual?.columnas || []).slice(0, 5).map((c) => c.nombre);
    this.filtros = [];
    this.ordenCampo = '';
    this.agregacionFuncion = '';
    this.agregacionCampo = '*';
    this.agruparPor = [];
  }

  toggleColumna(nombre: string): void {
    if (this.columnasSeleccionadas.includes(nombre)) {
      this.columnasSeleccionadas = this.columnasSeleccionadas.filter((c) => c !== nombre);
    } else {
      this.columnasSeleccionadas = [...this.columnasSeleccionadas, nombre];
    }
  }

  toggleAgrupacion(nombre: string): void {
    if (this.agruparPor.includes(nombre)) {
      this.agruparPor = this.agruparPor.filter((c) => c !== nombre);
    } else {
      this.agruparPor = [...this.agruparPor, nombre];
    }
  }

  nuevoFiltro(): void {
    const primera = this.tablaActual?.columnas[0]?.nombre || '';
    this.filtros.push({ campo: primera, operador: '=', valor: '', valorHasta: '', valores: '' });
  }

  quitarFiltro(i: number): void {
    this.filtros = this.filtros.filter((_, idx) => idx !== i);
  }

  construirEspec(): ConsultaEspec {
    const filtrosEspec: FiltroEspec[] = this.filtros
      .filter((f) => f.campo && f.operador)
      .map((f) => {
        const base: FiltroEspec = { campo: f.campo, operador: f.operador };
        if (f.operador === 'BETWEEN') {
          base.valor = f.valor;
          base.valorHasta = f.valorHasta;
        } else if (f.operador === 'IN') {
          base.valores = f.valores.split(',').map((v) => v.trim()).filter(Boolean);
        } else if (f.operador !== 'IS NULL' && f.operador !== 'IS NOT NULL') {
          base.valor = f.valor;
        }
        return base;
      });

    const orden: OrdenEspec[] = this.ordenCampo
      ? [{ campo: this.ordenCampo, direccion: this.ordenDireccion }]
      : [];

    return {
      entidad: this.entidad,
      columnas: this.columnasSeleccionadas,
      filtros: filtrosEspec,
      orden,
      limite: this.limite,
      agregacion: this.agregacionFuncion
        ? ({ funcion: this.agregacionFuncion, campo: this.agregacionCampo, agruparPor: this.agruparPor } as any)
        : null
    };
  }

  ejecutar(): void {
    this.ejecutando = true;
    this.errorMsg = '';
    this.reportes.consultar(this.construirEspec()).subscribe({
      next: (resultado) => {
        this.resultado = resultado;
        this.ejecutando = false;
      },
      error: (e) => {
        this.ejecutando = false;
        this.errorMsg = e.error?.message || 'La consulta fue rechazada.';
      }
    });
  }

  guardarConsulta(): void {
    if (!this.nombreConsulta.trim()) {
      this.errorMsg = 'Ponle un nombre a la consulta.';
      return;
    }
    this.reportes
      .guardar(this.nombreConsulta.trim(), this.entidad, JSON.stringify(this.construirEspec()))
      .subscribe({
        next: () => {
          this.nombreConsulta = '';
          this.cargarGuardadas();
        },
        error: (e) => (this.errorMsg = e.error?.message || 'No se pudo guardar.')
      });
  }

  cargarGuardadas(): void {
    this.reportes.listarGuardadas().subscribe({
      next: (g) => (this.guardadas = g),
      error: () => (this.guardadas = [])
    });
  }

  ejecutarGuardada(g: ConsultaGuardada): void {
    this.reportes.ejecutarGuardada(g.id).subscribe({
      next: (resultado) => (this.resultado = resultado),
      error: (e) => (this.errorMsg = e.error?.message || 'No se pudo ejecutar la consulta guardada.')
    });
  }

  eliminarGuardada(g: ConsultaGuardada): void {
    if (!confirm('¿Eliminar esta consulta guardada?')) return;
    this.reportes.eliminarGuardada(g.id).subscribe({ next: () => this.cargarGuardadas() });
  }

  exportar(tipo: 'pdf' | 'excel'): void {
    const spec = this.construirEspec();
    if (tipo === 'pdf') {
      const titulo = encodeURIComponent(`Reporte ${this.entidad}`);
      descargarBinario(`${environment.apiUrl}/reportes/exportar/pdf?titulo=${titulo}`, `reporte_${this.entidad}.pdf`, 'POST', spec)
        .catch((e) => (this.errorMsg = e.message));
    } else {
      descargarBinario(`${environment.apiUrl}/reportes/exportar/excel`, 'reporte.xlsx', 'POST', spec)
        .catch((e) => (this.errorMsg = e.message));
    }
  }

  filasResultado(): Record<string, unknown>[] {
    return this.resultado?.filas || [];
  }
}
