import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { DetalleEmpresa, PlataformaService, Transferencia } from '../registro/saas.service';
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
  detalle: DetalleEmpresa | null = null;
  cargando = true;
  errorMsg = '';
  filtro = '';
  entrando = 0;
  completando = 0;
  okMsg = '';
  /** Ronda 11: transferencias bancarias para conciliar depositos. */
  transferencias: Transferencia[] = [];
  /** Referencia de la transferencia que se esta procesando. */
  procesandoTransferencia = '';

  constructor(private plataforma: PlataformaService, private auth: AuthService, private router: Router) {}

  ngOnInit(): void {
    this.cargar();
    this.cargarTransferencias();
  }

  /** Ronda 11: lista las transferencias bancarias registradas. */
  cargarTransferencias(): void {
    this.plataforma.transferencias().subscribe({
      next: (lista) => (this.transferencias = lista || []),
      error: () => (this.transferencias = [])
    });
  }

  /** Confirma el deposito: la suscripcion de la empresa queda activa. */
  aprobarTransferencia(t: Transferencia): void {
    if (this.procesandoTransferencia) return;
    if (!confirm(`\u00bfConfirmar el deposito de "${t.empresa || t.referencia}" por Bs ${t.monto}?\n\nLa suscripcion quedara activa.`)) return;
    this.procesandoTransferencia = t.referencia;
    this.errorMsg = '';
    this.okMsg = '';
    this.plataforma.aprobarTransferencia(t.referencia).subscribe({
      next: (r) => {
        this.procesandoTransferencia = '';
        this.okMsg = r.mensaje || 'Transferencia confirmada.';
        this.cargarTransferencias();
      },
      error: (e) => {
        this.procesandoTransferencia = '';
        this.errorMsg = e?.error?.message || 'No se pudo confirmar la transferencia.';
      }
    });
  }

  /** Rechaza la transferencia (deposito no recibido o monto incorrecto). */
  rechazarTransferencia(t: Transferencia): void {
    if (this.procesandoTransferencia) return;
    const motivo = prompt('\u00bfPor que se rechaza la transferencia?', 'No se recibio el deposito');
    if (motivo === null) return;
    this.procesandoTransferencia = t.referencia;
    this.errorMsg = '';
    this.okMsg = '';
    this.plataforma.rechazarTransferencia(t.referencia, motivo).subscribe({
      next: (r) => {
        this.procesandoTransferencia = '';
        this.okMsg = r.mensaje || 'Transferencia rechazada.';
        this.cargarTransferencias();
      },
      error: (e) => {
        this.procesandoTransferencia = '';
        this.errorMsg = e?.error?.message || 'No se pudo rechazar la transferencia.';
      }
    });
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

  /**
   * Ronda 10: completa los datos de ejemplo de la empresa (para que ninguna
   * pantalla quede vacia). Solo crea lo que falta.
   */
  completarEjemplo(empresa: Empresa): void {
    if (this.completando) return;
    if (!confirm(`¿Completar los datos de ejemplo de "${empresa.nombre}"?\n\nSe crean categorias, areas, activos, presupuestos, mantenimientos e inventario de ejemplo SOLO si esa empresa no los tiene. No se pisa ningun dato real.`)) return;
    this.completando = empresa.id;
    this.errorMsg = '';
    this.okMsg = '';
    this.plataforma.completarDatosEjemplo(empresa.id).subscribe({
      next: (r) => {
        this.completando = 0;
        this.okMsg = r.estado === 'OK'
          ? `Datos de ejemplo listos para "${empresa.nombre}".`
          : `No se pudieron completar los datos de ejemplo (${r.estado}).`;
      },
      error: (e) => {
        this.completando = 0;
        this.errorMsg = e?.error?.message || 'No se pudieron completar los datos de ejemplo.';
      }
    });
  }

  /** Completa los datos de ejemplo de todas las empresas de la plataforma. */
  completarEjemploTodas(): void {
    if (this.completando) return;
    if (!confirm('¿Completar los datos de ejemplo de TODAS las empresas?\n\nSolo se crean los datos que falten; no se pisa nada real.')) return;
    this.completando = -1;
    this.errorMsg = '';
    this.okMsg = '';
    this.plataforma.completarDatosEjemploTodas().subscribe({
      next: (r) => {
        this.completando = 0;
        this.okMsg = `Datos de ejemplo completados en ${r.empresas} empresa(s).`;
        this.cargar();
      },
      error: (e) => {
        this.completando = 0;
        this.errorMsg = e?.error?.message || 'No se pudieron completar los datos de ejemplo.';
      }
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
