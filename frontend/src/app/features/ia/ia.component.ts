import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { IaService } from './ia.service';
import { EstadoIa, PruebaIa, RespuestaIa, TurnoHistorialIa } from '../../core/models/sprint3.models';

interface Mensaje {
  rol: 'usuario' | 'ia';
  texto: string;
  respuesta?: RespuestaIa;
  error?: boolean;
}

@Component({
  selector: 'app-ia',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './ia.component.html',
  styleUrl: './ia.component.scss'
})
export class IaComponent implements OnInit, OnDestroy {
  pregunta = '';
  enviando = false;
  mensajes: Mensaje[] = [];
  estadoIa: EstadoIa | null = null;
  pruebas: PruebaIa[] | null = null;
  probando = false;

  // HU-14 (voz): Web Speech API. No requiere claves ni servicios de pago y
  // funciona en Chrome/Edge; si el navegador no la soporta se escribe la pregunta.
  escuchando = false;
  vozDisponible = false;
  avisoVoz = '';
  private reconocimiento: any = null;
  private textoBase = '';

  // Ejemplos que funcionan incluso sin clave API (modo GUIADO del backend).
  ejemplos = [
    '¿Cuántos activos tiene la empresa?',
    'Lista los activos con valor mayor a 5000',
    '¿Cuál es el total del presupuesto aprobado?',
    'Muestra los mantenimientos pendientes'
  ];

  constructor(private ia: IaService) {}

  ngOnInit(): void {
    this.ia.estado().subscribe({
      next: (estado) => (this.estadoIa = estado),
      error: () => (this.estadoIa = null)
    });
    this.prepararVoz();
  }

  ngOnDestroy(): void {
    this.detenerVoz();
  }

  get iaConfigurada(): boolean {
    return !!this.estadoIa && (!!this.estadoIa.groqConfigurado || !!this.estadoIa.geminiConfigurado);
  }

  get hayFormatoInvalido(): boolean {
    if (!this.estadoIa) return false;
    return (!!this.estadoIa.groqConfigurado && this.estadoIa.groqFormatoValido === false)
      || (!!this.estadoIa.geminiConfigurado && this.estadoIa.geminiFormatoValido === false);
  }

  probarConexion(): void {
    if (this.probando) return;
    this.probando = true;
    this.pruebas = null;
    this.ia.probar().subscribe({
      next: (resultados) => {
        this.pruebas = resultados;
        this.probando = false;
      },
      error: (e) => {
        this.pruebas = [{
          proveedor: 'Sistema', modelo: '-', configurado: false, formatoClaveValido: false,
          ok: false, httpStatus: 0,
          detalle: e.error?.message || 'No se pudo ejecutar la prueba (revisa que el backend este en linea).'
        }];
        this.probando = false;
      }
    });
  }

  // ---------------------------------------------------------------- voz

  private prepararVoz(): void {
    const ventana = window as any;
    const Constructor = ventana.SpeechRecognition || ventana.webkitSpeechRecognition;
    if (!Constructor) {
      this.vozDisponible = false;
      return;
    }
    try {
      const r = new Constructor();
      r.lang = 'es-BO';
      r.continuous = false;
      r.interimResults = true;
      r.maxAlternatives = 1;

      r.onstart = () => {
        this.escuchando = true;
        this.avisoVoz = '';
      };

      r.onresult = (evento: any) => {
        let final = '';
        let parcial = '';
        for (let i = evento.resultIndex; i < evento.results.length; i++) {
          const resultado = evento.results[i];
          if (resultado.isFinal) {
            final += resultado[0].transcript;
          } else {
            parcial += resultado[0].transcript;
          }
        }
        if (final.trim()) {
          this.pregunta = (this.textoBase + final).trim();
        } else if (parcial.trim()) {
          this.pregunta = (this.textoBase + parcial).trim();
        }
      };

      r.onerror = (evento: any) => {
        this.escuchando = false;
        switch (evento?.error) {
          case 'not-allowed':
          case 'service-not-allowed':
            this.avisoVoz = 'El navegador bloqueó el micrófono. Permite el acceso desde el candado de la barra de direcciones y vuelve a intentarlo.';
            break;
          case 'no-speech':
            this.avisoVoz = 'No se escuchó nada. Pulsa el micrófono y habla de nuevo.';
            break;
          case 'network':
            this.avisoVoz = 'El servicio de voz del navegador no pudo conectarse. Revisa tu internet o escribe la pregunta.';
            break;
          case 'audio-capture':
            this.avisoVoz = 'No se encontró un micrófono disponible en este equipo.';
            break;
          default:
            this.avisoVoz = 'No se pudo usar el micrófono. Puedes escribir la pregunta o dictarla desde la app móvil.';
        }
      };

      r.onend = () => {
        this.escuchando = false;
      };

      this.reconocimiento = r;
      this.vozDisponible = true;
    } catch {
      this.vozDisponible = false;
    }
  }

  alternarVoz(): void {
    if (!this.vozDisponible || !this.reconocimiento) {
      this.avisoVoz = 'Este navegador no soporta dictado por voz. Usa Chrome o Edge, o escribe la pregunta (en la app móvil también puedes dictarla).';
      return;
    }
    if (this.escuchando) {
      this.detenerVoz();
      return;
    }
    this.textoBase = this.pregunta.trim() ? this.pregunta.trim() + ' ' : '';
    this.avisoVoz = 'Escuchando... habla ahora.';
    try {
      this.reconocimiento.lang = 'es-BO';
      this.reconocimiento.start();
      this.escuchando = true;
    } catch {
      this.escuchando = false;
      this.avisoVoz = 'El micrófono está ocupado por otra pestaña o aplicación. Ciérrala e inténtalo otra vez.';
    }
  }

  private detenerVoz(): void {
    try {
      this.reconocimiento?.stop();
    } catch {
      /* si ya estaba detenido no hay nada que hacer */
    }
    this.escuchando = false;
  }

  // ------------------------------------------------------------- consulta

  /** Ultimos 6 turnos para que el modelo entienda preguntas de seguimiento. */
  private construirHistorial(): TurnoHistorialIa[] {
    return this.mensajes
      .filter((m) => !m.error && m.texto && m.texto.trim().length > 0)
      .slice(-6)
      .map((m) => ({
        rol: m.rol === 'usuario' ? 'usuario' as const : 'asistente' as const,
        texto: m.texto.length > 500 ? m.texto.slice(0, 500) : m.texto
      }));
  }

  preguntar(texto?: string): void {
    const pregunta = (texto ?? this.pregunta).trim();
    if (!pregunta || this.enviando) return;
    this.detenerVoz();
    const historial = this.construirHistorial();
    this.mensajes.push({ rol: 'usuario', texto: pregunta });
    this.pregunta = '';
    this.enviando = true;
    this.ia.preguntar(pregunta, historial).subscribe({
      next: (respuesta) => {
        this.mensajes.push({ rol: 'ia', texto: respuesta.explicacion, respuesta });
        this.enviando = false;
      },
      error: (e) => {
        this.mensajes.push({
          rol: 'ia',
          texto: e.error?.message || 'No pude procesar la pregunta. Usa el constructor de reportes para una consulta guiada.',
          error: true
        });
        this.enviando = false;
      }
    });
  }

  etiquetaModo(modo: string, diagnostico?: string[]): string {
    switch (modo) {
      case 'GROQ': return 'Groq (IA en la nube)';
      case 'GEMINI': return 'Gemini (respaldo)';
      default:
        return diagnostico && diagnostico.length > 0
          ? 'Modo guiado (las llamadas a la IA fallaron)'
          : 'Modo guiado (sin clave de IA)';
    }
  }
}
