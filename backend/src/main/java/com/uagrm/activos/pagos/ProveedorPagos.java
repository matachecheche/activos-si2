package com.uagrm.activos.pagos;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Sprint 3: pasarela de pagos REAL (no simulada).
 *
 * Cada proveedor concreto (Mercado Pago, PayPal, Stripe, QR Simple) crea un
 * checkout en el sitio del proveedor y valida la notificacion que el proveedor
 * envia al backend. El sistema nunca marca un pago como aprobado por su cuenta: solo
 * lo hace cuando el proveedor confirma, y siempre consultando el estado en la
 * API del proveedor (server to server).
 */
public interface ProveedorPagos {

    /** Identificador del proveedor: MERCADO_PAGO | PAYPAL | STRIPE | QR. */
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

    /**
     * Consulta el estado de un pago ya creado (server a server). Permite que
     * la app pregunte "ya pago?" sin depender de que llego el webhook.
     * Por defecto el proveedor no lo permite.
     */
    default ResultadoPago verificar(String checkoutId) {
        return ResultadoPago.sinReferencia("Este proveedor no permite consultar el pago por codigo");
    }

    /**
     * Factor para convertir el monto de la suscripcion (bolivianos) a la
     * moneda que cobra el proveedor. Por defecto se usa el factor general.
     */
    default BigDecimal factorConversion(BigDecimal factorGeneral) {
        return factorGeneral;
    }

    /** Datos de la solicitud de pago. */
    record SolicitudCheckout(String referencia, String titulo, String descripcion,
                              BigDecimal monto, String correo, String moneda,
                              String urlExito, String urlFallo, String urlPendiente,
                              String urlWebhook) {
    }

    /**
     * Checkout creado: identificador y URL de pago.
     *
     * @param checkoutId      identificador del checkout en la pasarela.
     * @param urlPago         pagina donde el usuario paga (null en QR: el
     *                        usuario escanea un codigo, no navega a una URL).
     * @param estado          estado inicial informado por el proveedor.
     * @param qrImagenBase64  imagen PNG del codigo QR en base64 (solo QR).
     * @param datosBancarios  datos de la cuenta para depositar (solo
     *                        transferencia bancaria).
     */
    record CheckoutPago(String checkoutId, String urlPago, String estado, String qrImagenBase64,
                        Map<String, String> datosBancarios) {
        public CheckoutPago(String checkoutId, String urlPago, String estado) {
            this(checkoutId, urlPago, estado, null, null);
        }

        public CheckoutPago(String checkoutId, String urlPago, String estado, String qrImagenBase64) {
            this(checkoutId, urlPago, estado, qrImagenBase64, null);
        }
    }

    /** Resultado de verificar una notificacion. */
    record ResultadoPago(boolean aprobado, boolean rechazo, String referencia,
                          BigDecimal monto, String estadoProveedor, String detalle,
                          String mensaje, String checkoutId) {
        public ResultadoPago(boolean aprobado, boolean rechazo, String referencia,
                             BigDecimal monto, String estadoProveedor, String detalle,
                             String mensaje) {
            this(aprobado, rechazo, referencia, monto, estadoProveedor, detalle, mensaje, null);
        }

        public static ResultadoPago sinReferencia(String mensaje) {
            return new ResultadoPago(false, false, null, null, "IGNORADO", null, mensaje, null);
        }
    }
}
