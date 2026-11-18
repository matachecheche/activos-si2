import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { PlataformaService } from '../registro/saas.service';
import { AuthService } from '../../core/auth/auth.service';
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
  entrando = 0;

  constructor(private plataforma: PlataformaService, private auth: AuthService, private router: Router) {}

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

  /**
   * Entra a la empresa: el backend devuelve una sesion con el contexto de esa
   * empresa y la aplicacion se recarga para que todos los modulos (activos,
   * presupuestos, usuarios, respaldos...) muestren sus datos.
   */
  entrarComo(empresa: Empresa): void {
    if (this.entrando) return;
    if (!confirm(`¿Entrar a "${empresa.nombre}" con la sesión de Super Admin?`)) return;
    this.entrando = empresa.id;
    this.errorMsg = '';
    this.auth.entrarComoEmpresa(empresa.id).subscribe({
      next: () => {
        this.entrando = 0;
        window.location.reload();
      },
      error: (e) => {
        this.entrando = 0;
        this.errorMsg = e?.error?.message || 'No se pudo entrar a la empresa.';
      }
    });
  }
}
