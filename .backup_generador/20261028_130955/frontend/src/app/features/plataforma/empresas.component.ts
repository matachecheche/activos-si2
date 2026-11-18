import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PlataformaService } from '../registro/saas.service';
import { Empresa } from '../../core/models/sprint3.models';

@Component({
  selector: 'app-empresas-plataforma',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './empresas.component.html',
  styleUrl: './empresas.component.scss'
})
export class EmpresasPlataformaComponent implements OnInit {
  empresas: Empresa[] = [];
  metricas: Record<string, number> = {};
  detalle: Record<string, unknown> | null = null;
  cargando = true;
  errorMsg = '';
  filtro = '';

  constructor(private plataforma: PlataformaService) {}

  ngOnInit(): void {
    this.cargar();
  }

  cargar(): void {
    this.cargando = true;
    this.plataforma.empresas().subscribe({
      next: (empresas) => {
        this.empresas = empresas;
        this.cargando = false;
      },
      error: () => {
        this.errorMsg = 'No se pudo listar las empresas.';
        this.cargando = false;
      }
    });
    this.plataforma.metricas().subscribe({
      next: (metricas) => (this.metricas = metricas),
      error: () => undefined
    });
  }

  get empresasFiltradas(): Empresa[] {
    const q = this.filtro.trim().toLowerCase();
    if (!q) return this.empresas;
    return this.empresas.filter((e) =>
      `${e.nombre} ${e.nit} ${e.correoContacto ?? ''}`.toLowerCase().includes(q)
    );
  }

  verDetalle(id: number): void {
    this.plataforma.detalleEmpresa(id).subscribe({
      next: (d) => (this.detalle = d),
      error: () => (this.errorMsg = 'No se pudo obtener el detalle.')
    });
  }

  cambiarEstado(empresa: Empresa): void {
    const nuevoEstado = empresa.estado === 'ACTIVA' ? 'SUSPENDIDA' : 'ACTIVA';
    if (!confirm(`¿${nuevoEstado === 'ACTIVA' ? 'activar' : 'suspender'} a "${empresa.nombre}"?`)) return;
    this.plataforma.cambiarEstado(empresa.id, nuevoEstado).subscribe({
      next: (actualizada) => {
        const i = this.empresas.findIndex((e) => e.id === actualizada.id);
        if (i >= 0) this.empresas[i] = actualizada;
      },
      error: (e) => (this.errorMsg = e.error?.message || 'No se pudo cambiar el estado.')
    });
  }

  entradasMetrica(): Array<[string, number]> {
    return Object.entries(this.metricas);
  }
}
