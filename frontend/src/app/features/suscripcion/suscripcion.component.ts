import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { SaasService, SuscripcionService } from '../registro/saas.service';
import { Plan } from '../../core/models/sprint3.models';

@Component({
  selector: 'app-suscripcion',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './suscripcion.component.html',
  styleUrl: './suscripcion.component.scss'
})
export class SuscripcionComponent implements OnInit {
  info: Record<string, any> | null = null;
  planes: Plan[] = [];
  planSeleccionado: number | null = null;
  meses = 1;
  metodoPago: 'MERCADO_PAGO' | 'PAYPAL' | 'STRIPE' | 'QR' | 'TRANSFERENCIA' = 'MERCADO_PAGO';
  procesando = false;
  errorMsg = '';
  okMsg = '';
  /** Estado de la pasarela real (configurada, proveedor, moneda). */
  pasarela: Record<string, any> | null = null;
  /** Referencia del pago abierto para poder consultar su estado. */
  referenciaPago = '';
  /** Imagen del codigo QR (data URL) cuando el metodo de pago es QR. */
  qrImagen = '';
  /** Monto que se debe pagar (para mostrarlo junto al QR). */
  montoPasarela = '';
  /** Metodo de pago elegido para el cobro abierto. */
  metodoElegido = '';
  /** Ronda 11: datos de la cuenta bancaria (transferencia bancaria). */
  datosBancarios: Record<string, string> | null = null;
  /** Instrucciones del metodo de pago elegido. */
  instruccionesPago = '';

  /** true si ese metodo se puede cobrar de verdad en el servidor. */
  metodoDisponible(nombre: string): boolean {
    const lista = (this.pasarela?.['proveedoresDisponibles'] as any[]) || [];
    const m = lista.find((x) => x.nombre === nombre);
    return m ? m.configurado !== false : true;
  }

  mensajeMetodo(nombre: string): string {
    const lista = (this.pasarela?.['proveedoresDisponibles'] as any[]) || [];
    const m = lista.find((x) => x.nombre === nombre);
    return m && m.configurado === false
      ? `Este metodo no esta configurado en el servidor (${m.nombreVisible}).`
      : '';
  }

  constructor(private suscripcion: SuscripcionService, private saas: SaasService) {}

  ngOnInit(): void {
    this.cargar();
    this.cargarPasarela();
    this.saas.planesPublicos().subscribe({
      next: (planes) => {
        this.planes = planes;
        this.planSeleccionado = (this.info?.['plan'] as Plan)?.id ?? planes[0]?.id ?? null;
      }
    });
  }

  /** Consulta si la pasarela de pagos real esta configurada. */
  cargarPasarela(): void {
    this.suscripcion.estadoPasarela().subscribe({
      next: (info) => (this.pasarela = info),
      error: () => (this.pasarela = null)
    });
  }

  /**
   * Consulta el estado del pago abierto en la pasarela real (servidor a
   * servidor). Util cuando se paga con QR: el codigo se escanea fuera de la
   * aplicacion y la confirmacion puede tardar unos segundos.
   */
  consultarPago(): void {
    if (!this.referenciaPago) return;
    this.procesando = true;
    this.errorMsg = '';
    this.suscripcion.estadoPago(this.referenciaPago).subscribe({
      next: (info) => {
        this.procesando = false;
        const estado = (info['estado'] as string) || '';
        const mensaje = (info['mensaje'] as string) || '';
        if (estado === 'APROBADO') {
          this.okMsg = 'Pago confirmado: la suscripcion ya esta activa.';
          this.qrImagen = '';
          this.cargar();
        } else if (estado === 'RECHAZADO') {
          this.errorMsg = mensaje || 'El pago fue rechazado.';
        } else {
          this.okMsg = mensaje || 'Todavia no vemos el pago. Vuelve a comprobar en unos segundos.';
        }
      },
      error: (e) => {
        this.procesando = false;
        this.errorMsg = e.error?.message || 'No se pudo consultar el estado del pago.';
      }
    });
  }

  cargar(): void {
    this.suscripcion.miSuscripcion().subscribe({
      next: (info) => {
        this.info = info;
        const planActual = (info['plan'] as Plan)?.id;
        if (planActual) this.planSeleccionado = planActual;
      },
      error: (e) => (this.errorMsg = e.error?.message || 'Sin suscripción disponible.')
    });
  }

  /**
   * Contrata o renueva. Con pasarela real se abre el checkout del proveedor
   * (Mercado Pago o PayPal) y la suscripcion se activa sola cuando el
   * proveedor confirma el pago.
   */
  contratar(): void {
    if (!this.planSeleccionado) return;
    this.procesando = true;
    this.errorMsg = '';
    this.okMsg = '';
    this.datosBancarios = null;
    this.instruccionesPago = '';
    this.suscripcion.contratar(this.planSeleccionado, this.metodoPago, this.meses).subscribe({
      next: (res) => {
        this.procesando = false;
        const url = res['checkoutUrl'] as string | null;
        this.referenciaPago = (res['referencia'] as string) || '';
        this.metodoElegido = (res['proveedor'] as string) || '';
        this.qrImagen = (res['qrImagen'] as string) || '';
        this.montoPasarela = String(res['montoPasarela'] ?? '');
        this.datosBancarios = (res['datosBancarios'] as Record<string, string>) || null;
        this.instruccionesPago = (res['instrucciones'] as string) || (res['mensaje'] as string) || '';
        if (this.datosBancarios) {
          // Transferencia bancaria: se muestran los datos para depositar.
          this.okMsg = this.instruccionesPago || 'Transfiere el monto indicado usando la referencia.';
          this.cargar();
        } else if (this.qrImagen) {
          // QR: se muestra el codigo para escanearlo con la app del banco.
          this.okMsg = (res['mensaje'] as string) || 'Escanea el codigo QR para pagar.';
          this.cargar();
        } else if (url) {
          this.okMsg = 'Te llevamos a la pasarela de pago para completar la compra.';
          window.open(url, '_blank', 'noopener');
          this.cargar();
        } else {
          this.okMsg = (res['mensaje'] as string) || 'Pago registrado.';
          this.cargar();
        }
      },
      error: (e) => {
        this.procesando = false;
        this.errorMsg = e.error?.message || 'La contratación falló.';
      }
    });
  }
}
