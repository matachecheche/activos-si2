import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Plan, RegistroEmpresaRequest, Empresa } from '../../core/models/sprint3.models';

/** HU-11: registro publico de empresas y planes. */
@Injectable({ providedIn: 'root' })
export class SaasService {
  constructor(private http: HttpClient) {}

  planesPublicos(): Observable<Plan[]> {
    return this.http.get<Plan[]>(`${environment.apiUrl}/public/planes`);
  }

  registrarEmpresa(req: RegistroEmpresaRequest): Observable<unknown> {
    return this.http.post(`${environment.apiUrl}/public/registro-empresa`, req);
  }

  /** Metodos de pago disponibles (Stripe, QR, transferencia bancaria...). */
  metodosPago(): Observable<MetodoPago[]> {
    return this.http.get<MetodoPago[]>(`${environment.apiUrl}/public/metodos-pago`);
  }
}

/** Un metodo de pago y si esta realmente configurado en el servidor. */
export interface MetodoPago {
  nombre: string;
  nombreVisible: string;
  configurado: boolean;
  moneda: string;
  credencial: string;
  mensaje: string;
}

/** HU-11/HU-12: administracion de la suscripcion de la empresa. */
@Injectable({ providedIn: 'root' })
export class SuscripcionService {
  constructor(private http: HttpClient) {}

  miSuscripcion(): Observable<Record<string, unknown>> {
    return this.http.get<Record<string, unknown>>(`${environment.apiUrl}/suscripcion`);
  }

  contratar(planId: number, metodoPago: string, meses: number): Observable<Record<string, unknown>> {
    return this.http.post<Record<string, unknown>>(`${environment.apiUrl}/suscripcion/contratar`, { planId, metodoPago, meses });
  }

  /** Estado de la pasarela de pagos real (si esta configurada y con que moneda). */
  estadoPasarela(): Observable<Record<string, unknown>> {
    return this.http.get<Record<string, unknown>>(`${environment.apiUrl}/pagos/estado`);
  }

  /** Crea el checkout en la pasarela real y devuelve la URL de pago. */
  crearCheckout(planId: number, meses: number): Observable<Record<string, unknown>> {
    return this.http.post<Record<string, unknown>>(`${environment.apiUrl}/pagos/checkout`, { planId, meses });
  }

  /** Estado de un pago por su referencia. */
  estadoPago(referencia: string): Observable<Record<string, unknown>> {
    return this.http.get<Record<string, unknown>>(`${environment.apiUrl}/pagos/${referencia}`);
  }
}

/** Detalle de una empresa para el Super Admin: datos + conteos reales de uso. */
export interface DetalleEmpresa {
  empresa?: {
    id: number;
    nombre: string;
    nit: string;
    rubro?: string;
    correoContacto?: string;
    estado: string;
    fechaRegistro?: string;
  };
  suscripcion?: {
    id: number;
    estado: string;
    fechaInicio?: string;
    fechaVencimiento?: string;
    plan?: { id: number; nombre: string; precioMensual?: number; maxUsuarios?: number };
  };
  usuarios?: number;
  activos?: number;
  presupuestos?: number;
  mantenimientos?: number;
  respaldos?: number;
}

/** HU-12: Super Admin de la plataforma (metricas, empresas, suspension). */
@Injectable({ providedIn: 'root' })
export class PlataformaService {
  constructor(private http: HttpClient) {}

  empresas(): Observable<Empresa[]> {
    return this.http.get<Empresa[]>(`${environment.apiUrl}/plataforma/empresas`);
  }

  metricas(): Observable<Record<string, number>> {
    return this.http.get<Record<string, number>>(`${environment.apiUrl}/plataforma/metricas`);
  }

  detalleEmpresa(id: number): Observable<DetalleEmpresa> {
    return this.http.get<DetalleEmpresa>(`${environment.apiUrl}/plataforma/empresas/${id}`);
  }

  cambiarEstado(id: number, estado: 'ACTIVA' | 'SUSPENDIDA'): Observable<Empresa> {
    return this.http.post<Empresa>(`${environment.apiUrl}/plataforma/empresas/${id}/estado`, null, {
      params: { estado }
    });
  }

  /**
   * Ronda 10: completa los datos de ejemplo de una empresa (categorias, areas,
   * activos, presupuestos, mantenimiento, inventario...). Solo crea lo que le
   * falta: nunca pisa datos reales.
   */
  completarDatosEjemplo(id: number): Observable<{ estado: string; empresa?: string }> {
    return this.http.post<{ estado: string; empresa?: string }>(
      `${environment.apiUrl}/plataforma/empresas/${id}/datos-ejemplo`,
      null
    );
  }

  /** Completa los datos de ejemplo de todas las empresas de la plataforma. */
  completarDatosEjemploTodas(): Observable<{ empresas: number; completadas: number }> {
    return this.http.post<{ empresas: number; completadas: number }>(
      `${environment.apiUrl}/plataforma/datos-ejemplo`,
      null
    );
  }

  /** Transferencias bancarias registradas, para conciliar los depositos. */
  transferencias(): Observable<Transferencia[]> {
    return this.http.get<Transferencia[]>(`${environment.apiUrl}/plataforma/pagos/transferencias`);
  }

  /** Confirma el deposito: la suscripcion de la empresa queda activa. */
  aprobarTransferencia(referencia: string): Observable<{ mensaje: string }> {
    return this.http.post<{ mensaje: string }>(
      `${environment.apiUrl}/plataforma/pagos/transferencias/${referencia}/aprobar`,
      null
    );
  }

  /** Rechaza la transferencia (deposito no recibido o monto incorrecto). */
  rechazarTransferencia(referencia: string, motivo?: string): Observable<{ mensaje: string }> {
    return this.http.post<{ mensaje: string }>(
      `${environment.apiUrl}/plataforma/pagos/transferencias/${referencia}/rechazar`,
      null,
      { params: motivo ? { motivo } : {} }
    );
  }
}

/** Una transferencia bancaria registrada, pendiente de confirmar. */
export interface Transferencia {
  pagoId: number;
  referencia: string;
  estado: string;
  monto: number;
  metodo?: string;
  proveedor?: string;
  fecha?: string;
  fechaAprobacion?: string;
  empresaId?: number | null;
  empresa?: string | null;
  detalle?: string | null;
}
