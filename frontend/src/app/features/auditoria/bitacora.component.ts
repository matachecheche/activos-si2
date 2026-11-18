import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { BitacoraService } from './bitacora.service';
import { EntradaBitacora } from '../../core/models/sprint3.models';

@Component({
  selector: 'app-bitacora',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './bitacora.component.html',
  styleUrl: './bitacora.component.scss'
})
export class BitacoraComponent implements OnInit {
  entradas: EntradaBitacora[] = [];
  total = 0;
  pagina = 0;
  tamano = 20;
  cargando = false;
  errorMsg = '';

  filtros = { usuario: '', accion: '', entidad: '' };
  verificacion: { integra: boolean; registrosAlterados: number } | null = null;
  verificando = false;

  readonly acciones = [
    'LOGIN', 'REGISTRO_EMPRESA', 'PERSONALIZAR', 'RESPALDO', 'RESTAURAR',
    'BLOQUEO', 'VERIFICAR_INVENTARIO', 'RENOVACION'
  ];

  constructor(private service: BitacoraService) {}

  ngOnInit(): void {
    this.buscar();
  }

  buscar(pagina = 0): void {
    this.pagina = pagina;
    this.cargando = true;
    this.errorMsg = '';
    this.service.buscar({ ...this.filtros, pagina, tamano: this.tamano }).subscribe({
      next: (paginaResp) => {
        this.entradas = paginaResp.content;
        this.total = paginaResp.totalElements;
        this.cargando = false;
      },
      error: (e) => {
        this.errorMsg = e.error?.message || 'No se pudo consultar la bitácora.';
        this.cargando = false;
      }
    });
  }

  limpiar(): void {
    this.filtros = { usuario: '', accion: '', entidad: '' };
    this.buscar(0);
  }

  verificar(): void {
    this.verificando = true;
    this.service.verificarIntegridad().subscribe({
      next: (v) => {
        this.verificacion = v;
        this.verificando = false;
      },
      error: (e) => {
        this.errorMsg = e.error?.message || 'No se pudo verificar la integridad.';
        this.verificando = false;
      }
    });
  }

  get totalPaginas(): number {
    return Math.max(1, Math.ceil(this.total / this.tamano));
  }

  rangoPaginas(): number[] {
    const actual = this.pagina;
    const total = this.totalPaginas;
    const inicio = Math.max(0, actual - 2);
    const fin = Math.min(total - 1, actual + 2);
    const paginas: number[] = [];
    for (let i = inicio; i <= fin; i++) paginas.push(i);
    return paginas;
  }
}
