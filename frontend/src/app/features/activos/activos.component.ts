import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { ActivoService } from './activo.service';
import { ActivoFormComponent } from './activo-form.component';
import { Activo } from '../../core/models/activo.model';
import { Categoria } from '../../core/models/categoria.model';
import { CategoriaService } from '../../core/services/categoria.service';
import { AuthService } from '../../core/auth/auth.service';
import { claseBadge, etiqueta } from '../../core/util/formato';
import { mensajeError } from '../../core/util/http-error';

@Component({
  selector: 'app-activos',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, ActivoFormComponent],
  templateUrl: './activos.component.html',
  styleUrl: './activos.component.scss'
})
export class ActivosComponent implements OnInit {
  activos: Activo[] = [];
  categorias: Categoria[] = [];
  estados = ['DISPONIBLE', 'EN_USO', 'EN_MANTENIMIENTO', 'INACTIVO', 'DADO_DE_BAJA'];

  q = '';
  filtroEstado = '';
  filtroCategoria: number | '' = '';
  codigoBusqueda = '';

  error = '';
  mensaje = '';
  formularioAbierto = false;
  activoEnEdicion: Activo | null = null;

  etiqueta = etiqueta;
  claseBadge = claseBadge;

  constructor(
    private activoService: ActivoService,
    private categoriaService: CategoriaService,
    private router: Router,
    public auth: AuthService
  ) {}

  ngOnInit(): void {
    this.cargar();
    this.categoriaService.listar().subscribe({ next: (data) => (this.categorias = data), error: () => (this.categorias = []) });
  }

  cargar(): void {
    this.activoService.listar().subscribe({
      next: (data) => (this.activos = data),
      error: (err) => (this.error = mensajeError(err, 'No se pudieron cargar los activos.'))
    });
  }

  get filtrados(): Activo[] {
    const texto = this.q.trim().toLowerCase();
    return this.activos.filter((a) =>
      (!texto || a.codigo.toLowerCase().includes(texto) || a.nombre.toLowerCase().includes(texto)
        || (a.responsable?.nombre ?? '').toLowerCase().includes(texto))
      && (!this.filtroEstado || a.estado === this.filtroEstado)
      && (!this.filtroCategoria || a.categoriaId === Number(this.filtroCategoria)));
  }

  /** HU-05: buscar un activo por su codigo (el mismo que codifica el QR) y abrir su ficha. */
  buscarPorCodigo(): void {
    const codigo = this.codigoBusqueda.trim();
    this.error = '';
    if (!codigo) return;
    this.activoService.porCodigo(codigo).subscribe({
      next: (activo) => this.router.navigate(['/activos', activo.id]),
      error: (err) => (this.error = mensajeError(err, 'No existe un activo con ese código.'))
    });
  }

  nuevo(): void {
    this.mensaje = '';
    this.error = '';
    this.activoEnEdicion = null;
    this.formularioAbierto = true;
  }

  /** HU-02: solo se edita un activo sin movimientos asociados. */
  editar(a: Activo): void {
    this.mensaje = '';
    this.error = '';
    this.activoService.obtener(a.id).subscribe({
      next: (detalle) => {
        if (detalle.editable === false) {
          this.error = `El activo ${detalle.codigo} ya tiene movimientos asociados (asignaciones, estados o mantenimientos) y no puede editarse.`;
          return;
        }
        this.activoEnEdicion = detalle;
        this.formularioAbierto = true;
      },
      error: (err) => (this.error = mensajeError(err))
    });
  }

  alGuardar(activo: Activo): void {
    this.formularioAbierto = false;
    this.mensaje = `Activo ${activo.codigo} guardado correctamente.`;
    this.cargar();
  }
}
