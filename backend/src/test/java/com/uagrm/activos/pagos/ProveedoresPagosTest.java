package com.uagrm.activos.pagos;

import org.junit.jupiter.api.Test;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Pasarelas nuevas (Sprint 3): Stripe y QR Simple.
 *
 * Se prueban las partes que no necesitan red:
 *  - el estado de configuracion de cada proveedor;
 *  - la verificacion de la firma del webhook de Stripe (t=,v1=);
 *  - la conversion del monto a centavos de Stripe;
 *  - el rechazo de las notificaciones QR sin la credencial correcta.
 */
class ProveedoresPagosTest {

    private static final String SECRETO = "whsec_prueba_123";

    private StripeProveedor stripe(String clave, String secretoWebhook) {
        return new StripeProveedor(clave, secretoWebhook, "https://api.stripe.com", "USD", null);
    }

    @Test
    void stripeSinClaveNoEstaConfigurado() {
        assertFalse(stripe("", "").configurado());
        assertTrue(stripe("sk_test_123", "").configurado());
        assertEquals("STRIPE", stripe("sk_test_123", "").nombre());
        assertEquals("Stripe", stripe("sk_test_123", "").nombreVisible());
    }

    @Test
    void stripeRechazaEventoSinFirma() {
        StripeProveedor p = stripe("sk_test_123", SECRETO);
        var resultado = p.confirmarNotificacion("{\"type\":\"checkout.session.completed\"}", Map.of());
        assertFalse(resultado.aprobado());
        assertNull(resultado.referencia());
        assertTrue(resultado.mensaje().contains("Stripe-Signature"));
    }

    @Test
    void stripeRechazaFirmaInvalida() {
        StripeProveedor p = stripe("sk_test_123", SECRETO);
        String cab = "t=" + (System.currentTimeMillis() / 1000) + ",v1=deadbeef";
        var resultado = p.confirmarNotificacion("{\"type\":\"checkout.session.completed\"}",
                Map.of("stripe-signature", cab));
        assertFalse(resultado.aprobado());
        assertTrue(resultado.mensaje().toLowerCase().contains("firma"));
    }

    @Test
    void stripeRechazaFirmaVieja() throws Exception {
        StripeProveedor p = stripe("sk_test_123", SECRETO);
        // Firma correcta pero de hace mas de 5 minutos: Stripe la rechaza.
        long viejo = (System.currentTimeMillis() / 1000) - 3600;
        String cab = "t=" + viejo + ",v1=" + firma("t=" + viejo);
        var resultado = p.confirmarNotificacion("{}", Map.of("stripe-signature", cab));
        assertFalse(resultado.aprobado());
        assertTrue(resultado.mensaje().toLowerCase().contains("firma"));
    }

    @Test
    void stripeIgnoraEventosQueNoSonDeCheckout() {
        StripeProveedor p = stripe("sk_test_123", "");
        var resultado = p.confirmarNotificacion("{\"type\":\"customer.created\"}", Map.of());
        assertFalse(resultado.aprobado());
        assertNull(resultado.referencia());
    }

    @Test
    void stripeConvierteElMontoACentavos() throws Exception {
        // 12.34 USD -> 1234 centavos (Stripe cobra en la unidad menor).
        var metodo = StripeProveedor.class.getDeclaredMethod("aCentavos", BigDecimal.class, String.class);
        metodo.setAccessible(true);
        StripeProveedor p = stripe("sk_test_123", "");
        assertEquals(1234L, metodo.invoke(p, new BigDecimal("12.34"), "usd"));
        // Las monedas sin decimales (yen) se redondean a unidades enteras.
        assertEquals(12L, metodo.invoke(p, new BigDecimal("12.34"), "jpy"));
    }

    @Test
    void qrSimpleExigeCredencialesCompletas() {
        QrSimpleProveedor sinNada = new QrSimpleProveedor("", "", "", 0, "", 900, "x-api-key", "");
        assertFalse(sinNada.configurado());
        QrSimpleProveedor completo = new QrSimpleProveedor("cid", "secreto",
                "https://atcgwapitest.redenlace.com.bo/sandbox", 422717, "Activos Fijos", 900,
                "x-api-key", "valor");
        assertTrue(completo.configurado());
        assertEquals("QR", completo.nombre());
        assertEquals("BOB", completo.moneda());
    }

    @Test
    void qrSimpleRechazaNotificacionSinCredencial() {
        QrSimpleProveedor p = new QrSimpleProveedor("cid", "secreto",
                "https://atcgwapitest.redenlace.com.bo/sandbox", 422717, "Activos Fijos", 900,
                "x-api-key", "valor-secreto");
        var sinCabecera = p.confirmarNotificacion("{\"numeroReferencia\":\"123\"}", Map.of());
        assertFalse(sinCabecera.aprobado());
        assertTrue(sinCabecera.mensaje().toLowerCase().contains("credencial"));
        var conCredencialMala = p.confirmarNotificacion("{\"numeroReferencia\":\"123\"}",
                Map.of("x-api-key", "otra-cosa"));
        assertFalse(conCredencialMala.aprobado());
        assertTrue(conCredencialMala.mensaje().toLowerCase().contains("credencial"));
    }

    @Test
    void qrSimpleLimpiaLaReferenciaDelIntegrador() throws Exception {
        QrSimpleProveedor p = new QrSimpleProveedor("cid", "secreto",
                "https://atcgwapitest.redenlace.com.bo/sandbox", 422717, "Activos Fijos", 900,
                "x-api-key", "valor");
        var metodo = QrSimpleProveedor.class.getDeclaredMethod("referenciaValida", String.class);
        metodo.setAccessible(true);
        String limpia = (String) metodo.invoke(p, "PAG-1730000000-ABC123");
        assertEquals("PAG1730000000ABC123", limpia);
        assertTrue(limpia.length() <= 30);
    }

    /** Firma HMAC como la calcula Stripe: HMAC-SHA256("t.cuerpo", whsec_...). */
    private String firma(String prefijo) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(SECRETO.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal((prefijo + ".{}").getBytes(StandardCharsets.UTF_8)));
    }
}
