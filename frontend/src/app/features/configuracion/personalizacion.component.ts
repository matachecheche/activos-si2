import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PersonalizacionService } from './personalizacion.service';
import { TemaService } from '../../core/tema/tema.service';
import { IdiomaService } from '../../core/i18n/idioma.service';
import { VistaMarca } from '../../core/models/sprint3.models';

@Component({
  selector: 'app-personalizacion',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './personalizacion.component.html',
  styleUrl: './personalizacion.component.scss'
})
export class PersonalizacionComponent implements OnInit {
  colorPrimario = '#2c5cc5';
  colorSecundario = '#0f2a5c';
  idioma: 'es' | 'en' = 'es';
  posicionMenu: 'LATERAL' | 'SUPERIOR' = 'SUPERIOR';
  tieneLogo = false;
  logoNombre = '';
  guardando = false;
  subiendo = false;
  errorMsg = '';
  okMsg = '';
  readonly maximoLogo = 1024 * 1024;

  constructor(
    public service: PersonalizacionService,
    private tema: TemaService,
    private idiomaService: IdiomaService
  ) {}

  ngOnInit(): void {
    this.service.ver().subscribe({
      next: (marca) => this.aplicarVista(marca),
      error: () => undefined
    });
  }

  private aplicarVista(marca: VistaMarca): void {
    this.colorPrimario = marca.colorPrimario;
    this.colorSecundario = marca.colorSecundario;
    this.idioma = marca.idioma;
    this.tieneLogo = marca.tieneLogo;
    this.logoNombre = marca.logoNombre || '';
    try {
      const config = JSON.parse(marca.menuConfig || '[]');
      this.posicionMenu = config[0]?.posicion === 'LATERAL' ? 'LATERAL' : 'SUPERIOR';
    } catch {
      this.posicionMenu = 'SUPERIOR';
    }
  }

  previsualizar(): void {
    // Vista previa instantanea sobre las variables CSS, sin tocar backend aun.
    const root = document.documentElement.style;
    root.setProperty('--color-primario', this.colorPrimario);
    root.setProperty('--color-secundario', this.colorSecundario);
    this.idiomaService.cambiar(this.idioma);
  }

  guardar(): void {
    this.guardando = true;
    this.errorMsg = '';
    this.okMsg = '';
    const menuConfig = JSON.stringify([{ posicion: this.posicionMenu }]);
    this.service.guardar({
      colorPrimario: this.colorPrimario,
      colorSecundario: this.colorSecundario,
      idioma: this.idioma,
      menuConfig
    }).subscribe({
      next: () => {
        this.guardando = false;
        this.okMsg = 'Personalización guardada.';
        this.service.ver().subscribe((marca) => this.tema.aplicar(marca));
      },
      error: (e) => {
        this.guardando = false;
        this.errorMsg = e.error?.message || 'No se pudo guardar.';
      }
    });
  }

  seleccionarLogo(evento: Event): void {
    const input = evento.target as HTMLInputElement;
    const archivo = input.files?.[0];
    if (!archivo) return;
    if (archivo.size > this.maximoLogo) {
      this.errorMsg = 'El logo supera el máximo de 1 MB.';
      return;
    }
    this.subiendo = true;
    this.errorMsg = '';
    this.service.subirLogo(archivo).subscribe({
      next: (marca) => {
        this.subiendo = false;
        this.tieneLogo = true;
        this.logoNombre = marca.logoNombre || archivo.name;
        this.okMsg = 'Logo actualizado.';
      },
      error: (e) => {
        this.subiendo = false;
        this.errorMsg = e.error?.message || 'No se pudo subir el logo.';
      }
    });
  }

  quitarLogo(): void {
    if (!confirm('¿Quitar el logo de la empresa?')) return;
    this.service.quitarLogo().subscribe({
      next: () => {
        this.tieneLogo = false;
        this.logoNombre = '';
      }
    });
  }
}
