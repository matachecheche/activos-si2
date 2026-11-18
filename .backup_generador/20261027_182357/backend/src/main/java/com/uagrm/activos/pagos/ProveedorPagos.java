package com.uagrm.activos.pagos;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Sprint 3: pasarela de pagos REAL (no simulada).
 *
 * Cada proveedor concreto (Mercado Pago, PayPal) crea un checkout en el
 * sitio del proveedor y valida la notificacion que el proveedor envia al
 * backend. El sistema nunca marca un pago como aprobado por su cuenta: solo
 * lo hace cuando el proveedor confirma, y siempre consultando el estado en
 * la API del proveedor (server to server).
 */
public interface ProveedorPagos {

    /** Identificador del proveedor: MERCADO_PAGO | PAYPAL. */
    String nombre();

    /** Nombre para mostrar en la interfaz. */
    String nombreVisible();

    /** true si tiene las credenciales necesarias para operar. */
    boolean configurado();

    /** Moneda en la que cobra el proveedor (BOB, USD...). */
    String moneda();

    /** Crea el checkout y devuelve la URL donde el usuario paga. */
    CheckoutPago crearCheckout(SolicitudCheckout solicitud);

    /**
     * Procesa la notificacion del proveedor. Devuelve el resultado con el
     * estado real (verificado contra la API del proveedor).
     */
    ResultadoPago confirmarNotificacion(String cuerpo, Map<String, String> cabeceras);

    /** Datos de la solicitud de pago. */
    record SolicitudCheckout(String referencia, String titulo, String descripcion,
                              BigDecimal monto, String correo, String moneda,
                              String urlExito, String urlFallo, String urlPendiente,
                              String urlWebhook) {
    }

    /** Checkout creado: identificador y URL de pago. */
    record CheckoutPago(String checkoutId, String urlPago, String estado) {
    }

    /** Resultado de verificar una notificacion. */
    record ResultadoPago(boolean aprobado, boolean rechazo, String referencia,
                          BigDecimal monto, String estadoProveedor, String detalle,
                          String mensaje) {
        public static ResultadoPago sinReferencia(String mensaje) {
            return new ResultadoPago(false, false, null, null, "IGNORADO", null, mensaje);
        }
    }
}
