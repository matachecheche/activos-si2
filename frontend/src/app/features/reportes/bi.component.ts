import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReportesService } from './reportes.service';

interface FilaGrafico {
  etiqueta: string;
  valor: number;
}

@Component({
  selector: 'app-bi',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './bi.component.html',
  styleUrl: './bi.component.scss'
})
export class BiComponent implements OnInit {
  data: Record<string, any> = {};
  cargando = true;
  errorMsg = '';

  constructor(private reportes: ReportesService) {}

  ngOnInit(): void {
    this.reportes.tableroBi().subscribe({
      next: (data) => {
        this.data = data;
        this.cargando = false;
      },
      error: (e) => {
        this.errorMsg = e.error?.message || 'No se pudo cargar el tablero.';
        this.cargando = false;
      }
    });
  }

  get kpis(): Array<{ nombre: string; valor: string }> {
    const moneda = (v: unknown) => `Bs ${Number(v || 0).toLocaleString('es-BO', { maximumFractionDigits: 2 })}`;
    return [
      { nombre: 'Total de activos', valor: String(this.data_total('totalActivos')) },
      { nombre: 'Valor total de activos', valor: moneda(this.data['valorTotalActivos']) },
      { nombre: 'Depreciación acumulada', valor: moneda(this.data['depreciacionAcumulada']) },
      { nombre: 'Valor en libros', valor: moneda(this.data['valorEnLibros']) },
      { nombre: 'Mantenimientos pendientes', valor: String(this.data['mantenimientosPendientes'] ?? 0) },
      { nombre: 'Costo de mantenimientos', valor: moneda(this.data['costoMantenimientos']) }
    ];
  }

  private data_total(clave: string): number {
    return Number(this.data[clave] ?? 0);
  }

  estados(): FilaGrafico[] {
    return (this.data['activosPorEstado'] || []).map((f: any) => ({ etiqueta: f.estado, valor: Number(f.cantidad) }));
  }

  categorias(): FilaGrafico[] {
    return (this.data['activosPorCategoria'] || []).map((f: any) => ({ etiqueta: f.categoria, valor: Number(f.cantidad) }));
  }

  depreciacionMensual(): FilaGrafico[] {
    return (this.data['depreciacionMensual'] || []).map((f: any) => ({ etiqueta: f.periodo, valor: Number(f.monto) }));
  }

  presupuestos(): FilaGrafico[] {
    return (this.data['presupuestoPorGestion'] || []).map((f: any) => ({ etiqueta: String(f.gestion), valor: Number(f.aprobado) }));
  }

  maximo(filas: FilaGrafico[]): number {
    return Math.max(1, ...filas.map((f) => f.valor));
  }

  /** Geometria de barras SVG: altura proporcional sobre 160 px. */
  alturaBarra(valor: number, filas: FilaGrafico[]): number {
    return Math.round((valor / this.maximo(filas)) * 160);
  }

  /** Datos para el donut de estados (porcentajes acumulados). */
  segmentosDonut(): Array<{ etiqueta: string; valor: number; color: string; porcentaje: number }> {
    const paleta = ['#1769e0', '#15803d', '#b45309', '#be123c', '#7c3aed', '#0e7490'];
    const filas = this.estados();
    const total = filas.reduce((acc, f) => acc + f.valor, 0) || 1;
    let acumulado = 0;
    return filas.map((f, i) => {
      const porcentaje = (f.valor / total) * 100;
      const segmento = { etiqueta: f.etiqueta, valor: f.valor, color: paleta[i % paleta.length], porcentaje };
      acumulado += porcentaje;
      return segmento;
    });
  }

  donutCircunferencia = 2 * Math.PI * 70;

  dashArray(porcentaje: number): string {
    const longitud = (porcentaje / 100) * this.donutCircunferencia;
    return `${longitud} ${this.donutCircunferencia - longitud}`;
  }

  dashOffset(indice: number): number {
    const previo = this.segmentosDonut().slice(0, indice).reduce((acc, s) => acc + s.porcentaje, 0);
    return -(previo / 100) * this.donutCircunferencia;
  }
}
