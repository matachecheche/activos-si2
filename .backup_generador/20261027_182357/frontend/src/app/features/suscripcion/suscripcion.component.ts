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
  metodoPago: 'MERCADO_PAGO' | 'PAYPAL' | 'TRANSFERENCIA' = 'MERCADO_PAGO';
  procesando = false;
  errorMsg = '';
  okMsg = '';
  /** Estado de la pasarela real (configurada, proveedor, moneda). */
  pasarela: Record<string, any> | null = null;
  /** Referencia del pago abierto para poder consultar su estado. */
  referenciaPago = '';

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
    this.suscripcion.contratar(this.planSeleccionado, this.metodoPago, this.meses).subscribe({
      next: (res) => {
        this.procesando = false;
        const url = res['checkoutUrl'] as string | null;
        this.referenciaPago = (res['referencia'] as string) || '';
        if (url) {
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
