import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RespaldosService } from './respaldos.service';
import { Respaldo, ProgramacionRespaldo } from '../../core/models/sprint3.models';
import { descargarBinario } from '../../core/util/descarga';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-respaldos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './respaldos.component.html',
  styleUrl: './respaldos.component.scss'
})
export class RespaldosComponent implements OnInit {
  respaldos: Respaldo[] = [];
  programacion: ProgramacionRespaldo = {
    frecuencia: 'DIARIA',
    hora: '02:00',
    copiasAConservar: 3,
    destino: 'LOCAL',
    activa: true
  };
  trabajando = false;
  errorMsg = '';
  okMsg = '';

  constructor(private service: RespaldosService) {}

  ngOnInit(): void {
    this.cargar();
    this.service.verProgramacion().subscribe({
      next: (p) => { if (p) this.programacion = p; },
      error: () => undefined
    });
  }

  cargar(): void {
    this.service.listar().subscribe({
      next: (respaldos) => (this.respaldos = respaldos),
      error: (e) => (this.errorMsg = e.error?.message || 'No se pudieron listar los respaldos.')
    });
  }

  crear(): void {
    this.trabajando = true;
    this.okMsg = '';
    this.errorMsg = '';
    this.service.crear().subscribe({
      next: () => {
        this.trabajando = false;
        this.okMsg = 'Respaldo creado y verificado con SHA-256.';
        this.cargar();
      },
      error: (e) => {
        this.trabajando = false;
        this.errorMsg = e.error?.message || 'No se pudo crear el respaldo.';
      }
    });
  }

  descargar(r: Respaldo): void {
    descargarBinario(`${environment.apiUrl}/respaldos/${r.id}/descargar`, r.nombreArchivo || `respaldo_${r.id}.afb`)
      .catch((e) => (this.errorMsg = e.message));
  }

  restaurar(r: Respaldo): void {
    if (!confirm(`¿Restaurar la empresa desde el respaldo "${r.archivo}"?\n\nSe creará antes un respaldo de seguridad y la operación es transaccional: si algo falla, todo vuelve a su estado original.`)) return;
    this.trabajando = true;
    this.errorMsg = '';
    this.service.restaurar(r.id).subscribe({
      next: () => {
        this.trabajando = false;
        this.okMsg = 'Restauración completada correctamente.';
        this.cargar();
      },
      error: (e) => {
        this.trabajando = false;
        this.errorMsg = e.error?.message || 'La restauración falló; los datos permanecen intactos.';
      }
    });
  }

  guardarProgramacion(): void {
    this.trabajando = true;
    this.service.guardarProgramacion(this.programacion).subscribe({
      next: (p) => {
        this.programacion = p;
        this.trabajando = false;
        this.okMsg = 'Programación guardada.';
      },
      error: (e) => {
        this.trabajando = false;
        this.errorMsg = e.error?.message || 'No se pudo guardar la programación.';
      }
    });
  }

  tamano(bytes: number): string {
    if (!bytes) return '0 B';
    const unidades = ['B', 'KB', 'MB', 'GB'];
    const i = Math.min(unidades.length - 1, Math.floor(Math.log(bytes) / Math.log(1024)));
    return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${unidades[i]}`;
  }
}
