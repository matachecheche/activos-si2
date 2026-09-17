import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivoService } from './activo.service';
import { Activo } from '../../core/models/activo.model';
import { Categoria } from '../../core/models/categoria.model';
import { CategoriaService } from '../../core/services/categoria.service';

@Component({
  selector: 'app-activos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './activos.component.html',
  styleUrl: './activos.component.scss'
})
export class ActivosComponent implements OnInit {
  activos: Activo[] = [];
  categorias: Categoria[] = [];
  mostrarFormulario = false;

  nuevo: Activo = {
    nombre: '',
    categoriaId: 0,
    valor: 0,
    fechaAdquisicion: ''
  };

  constructor(
    private activoService: ActivoService,
    private categoriaService: CategoriaService
  ) {}

  ngOnInit(): void {
    this.cargarActivos();
    this.categoriaService.listar().subscribe((data) => {
      this.categorias = data;
      if (data.length) { this.nuevo.categoriaId = data[0].id; }
    });
  }

  cargarActivos(): void {
    this.activoService.listar().subscribe((data) => (this.activos = data));
  }

  nombreCategoria(id: number): string {
    return this.categorias.find((c) => c.id === id)?.nombre ?? '-';
  }

  claseEstado(estado?: string): string {
    switch (estado) {
      case 'EN_USO': return 'badge badge-uso';
      case 'MANTENIMIENTO': return 'badge badge-mantenimiento';
      case 'BAJA': return 'badge badge-baja';
      default: return 'badge badge-sin-asignar';
    }
  }

  registrar(): void {
    this.activoService.registrar(this.nuevo).subscribe(() => {
      this.nuevo = {
        nombre: '',
        categoriaId: this.categorias[0]?.id ?? 0,
        valor: 0,
        fechaAdquisicion: ''
      };
      this.mostrarFormulario = false;
      this.cargarActivos();
    });
  }
}
