package com.uagrm.activos.pagos;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Transferencia bancaria: un metodo de pago REAL que no depende de un
 * intermediario Electronico.
 *
 * <p>Como en un banco no hay webhook, el flujo es el siguiente:</p>
 * <ol>
 *   <li>La empresa elige "Transferencia bancaria" y el sistema genera una
 *       orden de pago con un codigo de referencia unico.</li>
 *   <li>Se le muestran los datos de la cuenta (banco, numero de cuenta,
 *       titular, NIT/CI y sucursal) y el monto exacto a depositar.</li>
 *   <li>El pago queda PENDIENTE. El administrador de la plataforma (o el
 *       de la empresa) verifica el deposito y lo APRUEBA: en ese momento se
 *       activa la suscripcion, igual que con una pasarela en linea.</li>
 * </ol>
 *
 * <p>Los datos bancarios se configuran por variables de entorno
 * (APP_PAGOS_TRANSFERENCIA_BANCO, _CUENTA, _TITULAR, _NIT, _SUCURSAL). Si
 * faltan, el proveedor informa que no esta configurado y la interfaz lo
 * dice con claridad: nunca se simula un pago.</p>
 */
@Component
public class TransferenciaProveedor implements ProveedorPagos {

    private static final Logger log = LoggerFactory.getLogger(TransferenciaProveedor.class);

    private final String banco;
    private final String cuenta;
    private final String titular;
    private final String nit;
    private final String sucursal;
    private final String monedaPorDefecto;
    private final String instrucciones;

    public TransferenciaProveedor(
            @Value("${app.pagos.transferencia.banco:}") String banco,
            @Value("${app.pagos.transferencia.cuenta:}") String cuenta,
            @Value("${app.pagos.transferencia.titular:}") String titular,
            @Value("${app.pagos.transferencia.nit:}") String nit,
            @Value("${app.pagos.transferencia.sucursal:}") String sucursal,
            @Value("${app.pagos.transferencia.moneda:BOB}") String monedaPorDefecto,
            @Value("${app.pagos.transferencia.instrucciones:}") String instrucciones) {
        this.banco = limpiar(banco);
        this.cuenta = limpiar(cuenta);
        this.titular = limpiar(titular);
        this.nit = limpiar(nit);
        this.sucursal = limpiar(sucursal);
        this.monedaPorDefecto = monedaPorDefecto == null || monedaPorDefecto.isBlank()
                ? "BOB" : monedaPorDefecto.trim().toUpperCase();
        this.instrucciones = limpiar(instrucciones);
    }

    private static String limpiar(String valor) {
        return valor == null ? "" : valor.trim();
    }

    @Override
    public String nombre() {
        return "TRANSFERENCIA";
    }

    @Override
    public String nombreVisible() {
        return "Transferencia bancaria";
    }

    /** Configurada cuando hay banco y numero de cuenta donde depositar. */
    @Override
    public boolean configurado() {
        return !banco.isBlank() && !cuenta.isBlank();
    }

    @Override
    public String moneda() {
        return monedaPorDefecto;
    }

    /** No hay conversion: el deposito es en bolivianos. */
    @Override
    public BigDecimal factorConversion(BigDecimal factorGeneral) {
        return BigDecimal.ONE;
    }

    /**
     * Crea la orden de pago. No hay llamada externa: la "orden" es el codigo
     * de referencia mas los datos de la cuenta donde hay que depositar.
     */
    @Override
    public CheckoutPago crearCheckout(SolicitudCheckout solicitud) {
        Map<String, String> datos = new LinkedHashMap<>();
        datos.put("banco", banco);
        datos.put("cuenta", cuenta);
        datos.put("titular", titular);
        datos.put("nit", nit);
        datos.put("sucursal", sucursal);
        datos.put("moneda", solicitud.moneda() == null ? monedaPorDefecto : solicitud.moneda());
        datos.put("instrucciones", instrucciones.isBlank()
                ? "Realiza la transferencia por el monto indicado usando el codigo de referencia. "
                  + "La suscripcion se activa en cuanto el administrador confirme el deposito."
                : instrucciones);
        log.info("Orden de transferencia creada: referencia {} ({} {})", solicitud.referencia(),
                solicitud.monto(), solicitud.moneda());
        // La URL es la propia pantalla de suscripcion: alli se consulta el estado.
        return new CheckoutPago(solicitud.referencia(), solicitud.urlPendiente(), "PENDIENTE", null, datos);
    }

    /**
     * No hay webhook: la confirmacion la hace el administrador de la
     * plataforma (ver PagosService.aprobarTransferencia).
     */
    @Override
    public ResultadoPago confirmarNotificacion(String cuerpo, Map<String, String> cabeceras) {
        return ResultadoPago.sinReferencia(
                "La transferencia bancaria se confirma a mano: un administrador aprueba el deposito.");
    }

    @Override
    public ResultadoPago verificar(String checkoutId) {
        return ResultadoPago.sinReferencia(
                "El estado de una transferencia lo confirma el administrador de la plataforma.");
    }

    /** Datos bancarios para mostrarlos en la interfaz. */
    public Map<String, String> datosBancarios() {
        Map<String, String> datos = new LinkedHashMap<>();
        datos.put("banco", banco);
        datos.put("cuenta", cuenta);
        datos.put("titular", titular);
        datos.put("nit", nit);
        datos.put("sucursal", sucursal);
        datos.put("moneda", monedaPorDefecto);
        return datos;
    }
}
