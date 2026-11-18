import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { InventarioService } from './inventario.service';
import { VerificacionInventario } from '../../core/models/sprint3.models';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-inventario',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './inventario.component.html',
  styleUrl: './inventario.component.scss'
})
export class InventarioComponent implements OnInit {
  estadisticas: Record<string, number> = {};
  verificaciones: VerificacionInventario[] = [];
  cargando = false;
  errorMsg = '';
  okMsg = '';
  pagina = 0;
  tamano = 20;
  total = 0;

  form = {
    activoId: null as number | null,
    resultado: 'ENCONTRADO' as string,
    observacion: '',
    latitud: null as number | null,
    longitud: null as number | null,
    precisionM: null as number | null,
    fotoUrl: ''
  };
  gpsBuscando = false;
  subiendoFoto = false;
  readonly resultados = ['ENCONTRADO', 'NO_ENCONTRADO', 'DIFERENCIA_ESTADO'];

  constructor(private service: InventarioService) {}

  ngOnInit(): void {
    this.cargarStats();
    this.cargar(0);
  }

  /** Etiquetas en espanol para las tarjetas; el backend tambien devuelve
   *  'ultimas' (un array de objetos), que nunca debe pintarse como tarjeta. */
  readonly etiquetasStats: Record<string, string> = {
    encontrados: 'ENCONTRADOS',
    noEncontrados: 'NO ENCONTRADOS',
    diferenciaEstado: 'DIFERENCIAS DE ESTADO'
  };

  /** Solo los contadores numericos, sin la clave 'ultimas' (que es una lista). */
  get contadores(): { clave: string; valor: number }[] {
    return Object.entries(this.estadisticas)
      .filter(([clave, valor]) => clave !== 'ultimas' && typeof valor === 'number')
      .map(([clave, valor]) => ({ clave, valor: valor as number }));
  }

  cargarStats(): void {
    this.service.estadisticas().subscribe({
      next: (s) => (this.estadisticas = s),
      error: () => undefined
    });
  }

  cargar(pagina: number): void {
    this.pagina = pagina;
    this.cargando = true;
    this.service.listar(pagina, this.tamano).subscribe({
      next: (p) => {
        this.verificaciones = p.content;
        this.total = p.totalElements;
        this.cargando = false;
      },
      error: (e) => {
        this.errorMsg = e.error?.message || 'No se pudo cargar el inventario.';
        this.cargando = false;
      }
    });
  }

  /** HU-17: captura GPS con permiso; siempre existe la alternativa manual. */
  capturarGps(): void {
    if (!('geolocation' in navigator)) {
      this.errorMsg = 'Este navegador no soporta geolocalización. Ingresa las coordenadas manualmente.';
      return;
    }
    this.gpsBuscando = true;
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        this.form.latitud = pos.coords.latitude;
        this.form.longitud = pos.coords.longitude;
        this.form.precisionM = pos.coords.accuracy;
        this.gpsBuscando = false;
      },
      () => {
        this.gpsBuscando = false;
        this.errorMsg = 'Permiso de ubicación denegado. Puedes registrar la verificación sin GPS o ingresar coordenadas manuales.';
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  subirFoto(evento: Event): void {
    const input = evento.target as HTMLInputElement;
    const archivo = input.files?.[0];
    if (!archivo) return;
    this.subiendoFoto = true;
    this.service.subirFoto(archivo).subscribe({
      next: (r) => {
        this.form.fotoUrl = r.fotoUrl;
        this.subiendoFoto = false;
        this.okMsg = 'Foto adjuntada.';
      },
      error: (e) => {
        this.subiendoFoto = false;
        this.errorMsg = e.error?.message || 'No se pudo subir la foto.';
      }
    });
  }

  registrar(): void {
    if (!this.form.activoId) {
      this.errorMsg = 'Indica el ID del activo verificado.';
      return;
    }
    this.errorMsg = '';
    const payload = {
      activoId: this.form.activoId as number,
      resultado: this.form.resultado,
      observacion: this.form.observacion,
      latitud: this.form.latitud,
      longitud: this.form.longitud,
      precisionM: this.form.precisionM,
      fotoUrl: this.form.fotoUrl
    };
    this.service.verificar(payload).subscribe({
      next: () => {
        this.okMsg = 'Verificación registrada.';
        this.form = { activoId: null, resultado: 'ENCONTRADO', observacion: '', latitud: null, longitud: null, precisionM: null, fotoUrl: '' };
        this.cargar(0);
        this.cargarStats();
      },
      error: (e) => (this.errorMsg = e.error?.message || 'No se pudo registrar la verificación.')
    });
  }

  urlFoto(relativa: string): string {
    if (!relativa) return '';
    // El backend devuelve rutas relativas que ya incluyen el prefijo /api.
    return relativa.startsWith('http') || relativa.startsWith('/api/') ? relativa : `${environment.apiUrl}/${relativa}`;
  }

  get totalPaginas(): number {
    return Math.max(1, Math.ceil(this.total / this.tamano));
  }
}
