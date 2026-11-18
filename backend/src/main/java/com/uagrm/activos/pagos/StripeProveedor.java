package com.uagrm.activos.pagos;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;

/**
 * Stripe (Checkout Sessions) con REST real.
 *
 * - Crea una sesion de checkout (hosted) y devuelve su URL.
 * - El webhook se valida con la FIRMA de Stripe (cabecera Stripe-Signature):
 *   t=timestamp,v1=HMAC-SHA256(t + "." + cuerpo, secreto del webhook).
 *   Ademas, aunque la firma cuadre, el pago se vuelve a consultar en la API
 *   de Stripe (server a server) antes de aprobarlo.
 *
 * Credenciales: STRIPE_SECRET_KEY (sk_test_... / sk_live_...) y
 * STRIPE_WEBHOOK_SECRET (whsec_...).
 */
@Component
public class StripeProveedor implements ProveedorPagos {

    private static final Logger log = LoggerFactory.getLogger(StripeProveedor.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    /** Segundos de tolerancia para la marca de tiempo de la firma (como Stripe). */
    private static final long TOLERANCIA_FIRMA_SEG = 300;

    private final String secretKey;
    private final String webhookSecret;
    private final String baseUrl;
    private final String monedaPorDefecto;
    private final BigDecimal factor;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15)).build();

    public StripeProveedor(
            @Value("${app.pagos.stripe.secret-key:}") String secretKey,
            @Value("${app.pagos.stripe.webhook-secret:}") String webhookSecret,
            @Value("${app.pagos.stripe.base-url:https://api.stripe.com}") String baseUrl,
            @Value("${app.pagos.stripe.moneda:USD}") String monedaPorDefecto,
            @Value("${app.pagos.stripe.factor-conversion:}") BigDecimal factor) {
        this.secretKey = secretKey == null ? "" : secretKey.trim();
        this.webhookSecret = webhookSecret == null ? "" : webhookSecret.trim();
        this.baseUrl = (baseUrl == null || baseUrl.isBlank() ? "https://api.stripe.com" : baseUrl.trim())
                .replaceAll("/+$", "");
        this.monedaPorDefecto = monedaPorDefecto == null || monedaPorDefecto.isBlank()
                ? "USD" : monedaPorDefecto.trim().toLowerCase();
        this.factor = factor;
    }

    @Override
    public BigDecimal factorConversion(BigDecimal factorGeneral) {
        return factor == null || factor.signum() <= 0 ? factorGeneral : factor;
    }

    @Override
    public String nombre() {
        return "STRIPE";
    }

    @Override
    public String nombreVisible() {
        return "Stripe";
    }

    @Override
    public boolean configurado() {
        return !secretKey.isBlank();
    }

    @Override
    public String moneda() {
        return monedaPorDefecto.toUpperCase();
    }

    @Override
    public CheckoutPago crearCheckout(SolicitudCheckout solicitud) {
        if (!configurado()) {
            throw new IllegalStateException("Stripe no esta configurado (falta STRIPE_SECRET_KEY)");
        }
        try {
            String moneda = solicitud.moneda() == null || solicitud.moneda().isBlank()
                    ? monedaPorDefecto : solicitud.moneda().trim().toLowerCase();
            long centavos = aCentavos(solicitud.monto(), moneda);
            List<String> params = new ArrayList<>();
            params.add("mode=payment");
            params.add("line_items[0][price_data][currency]=" + url(moneda));
            params.add("line_items[0][price_data][unit_amount]=" + centavos);
            params.add("line_items[0][price_data][product_data][name]=" + url(solicitud.titulo()));
            params.add("line_items[0][price_data][product_data][description]=" + url(solicitud.descripcion()));
            params.add("line_items[0][quantity]=1");
            params.add("client_reference_id=" + url(solicitud.referencia()));
            params.add("metadata[referencia]=" + url(solicitud.referencia()));
            if (solicitud.correo() != null && !solicitud.correo().isBlank()) {
                params.add("customer_email=" + url(solicitud.correo()));
            }
            params.add("success_url=" + url(solicitud.urlExito()));
            params.add("cancel_url=" + url(solicitud.urlFallo()));
            params.add("payment_intent_data[metadata][referencia]=" + url(solicitud.referencia()));

            HttpResponse<String> respuesta = enviar("POST", "/v1/checkout/sessions", params);
            if (respuesta.statusCode() >= 300) {
                throw new IllegalStateException("Stripe rechazo la sesion de checkout (HTTP "
                        + respuesta.statusCode() + "): " + recortar(respuesta.body()));
            }
            JsonNode json = MAPPER.readTree(respuesta.body());
            String id = json.path("id").asText("");
            String url = json.path("url").asText("");
            if (id.isBlank()) {
                throw new IllegalStateException("Stripe no devolvio el identificador de la sesion");
            }
            String estado = json.path("payment_status").asText(json.path("status").asText("open"));
            return new CheckoutPago(id, url, estado);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo comunicar con Stripe: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La llamada a Stripe fue interrumpida", e);
        }
    }

    @Override
    public ResultadoPago confirmarNotificacion(String cuerpo, Map<String, String> cabeceras) {
        if (!configurado()) {
            return ResultadoPago.sinReferencia("Stripe no esta configurado");
        }
        String payload = cuerpo == null ? "" : cuerpo;
        String firma = cabeceras == null ? null : cabeceras.get("stripe-signature");
        if (firma == null || firma.isBlank()) {
            return ResultadoPago.sinReferencia("Notificacion de Stripe sin la cabecera Stripe-Signature");
        }
        if (!webhookSecret.isBlank() && !firmaValida(payload, firma)) {
            log.warn("Notificacion de Stripe con firma invalida");
            return ResultadoPago.sinReferencia("Firma de Stripe invalida: el evento no se procesa");
        }
        if (webhookSecret.isBlank()) {
            log.warn("STRIPE_WEBHOOK_SECRET no esta definido: se verifica solo contra la API de Stripe");
        }
        try {
            JsonNode evento = MAPPER.readTree(payload);
            String tipo = evento.path("type").asText("");
            JsonNode objeto = evento.path("data").path("object");
            if (!tipo.startsWith("checkout.session.")) {
                return ResultadoPago.sinReferencia("Evento de Stripe ignorado: " + tipo);
            }
            if (!"checkout.session.completed".equals(tipo)
                    && !"checkout.session.async_payment_succeeded".equals(tipo)) {
                return ResultadoPago.sinReferencia("Evento de Stripe sin pago completado: " + tipo);
            }
            String idSesion = objeto.path("id").asText("");
            if (idSesion.isBlank()) {
                return ResultadoPago.sinReferencia("El evento de Stripe no trae la sesion de checkout");
            }
            // Verificacion server to server: el evento no se aprueba solo.
            return verificar(idSesion);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo leer la notificacion de Stripe: " + e.getMessage(), e);
        }
    }

    @Override
    public ResultadoPago verificar(String checkoutId) {
        if (!configurado()) {
            return ResultadoPago.sinReferencia("Stripe no esta configurado");
        }
        if (checkoutId == null || checkoutId.isBlank()) {
            return ResultadoPago.sinReferencia("Falta el identificador del checkout de Stripe");
        }
        try {
            HttpResponse<String> respuesta = enviar("GET", "/v1/checkout/sessions/" + url(checkoutId), List.of());
            if (respuesta.statusCode() >= 300) {
                return new ResultadoPago(false, false, null, null, "NO_VERIFICADO", null,
                        "Stripe no confirmo la sesion (HTTP " + respuesta.statusCode() + ")", checkoutId);
            }
            JsonNode sesion = MAPPER.readTree(respuesta.body());
            String estadoPago = sesion.path("payment_status").asText("");
            String estado = sesion.path("status").asText("");
            String referencia = sesion.path("client_reference_id").asText("");
            if (referencia.isBlank()) {
                referencia = sesion.path("metadata").path("referencia").asText("");
            }
            BigDecimal monto = sesion.path("amount_total").isNumber()
                    ? new BigDecimal(sesion.path("amount_total").asLong()).movePointLeft(2)
                    : null;
            String moneda = sesion.path("currency").asText("");
            String detalle = MAPPER.writeValueAsString(Map.of(
                    "id", checkoutId,
                    "estado", estado,
                    "estadoPago", estadoPago,
                    "moneda", moneda));
            boolean aprobado = "paid".equalsIgnoreCase(estadoPago);
            boolean rechazado = "unpaid".equalsIgnoreCase(estadoPago) && "expired".equalsIgnoreCase(estado);
            return new ResultadoPago(aprobado, rechazado, referencia, monto, estadoPago, detalle,
                    aprobado ? "Pago aprobado por Stripe" : "El pago sigue en estado " + estadoPago,
                    checkoutId);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo verificar el pago en Stripe: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La verificacion del pago fue interrumpida", e);
        }
    }

    /** Firma de Stripe: HMAC-SHA256 de "t.cuerpo" con el secreto whsec_. */
    private boolean firmaValida(String payload, String cabecera) {
        long timestamp = -1;
        List<String> firmas = new ArrayList<>();
        for (String parte : cabecera.split(",")) {
            String p = parte.trim();
            if (p.startsWith("t=")) {
                try {
                    timestamp = Long.parseLong(p.substring(2));
                } catch (NumberFormatException ignored) {
                    // se ignora: la marca de tiempo no es valida
                }
            } else if (p.startsWith("v1=")) {
                firmas.add(p.substring(3));
            }
        }
        if (timestamp < 0 || firmas.isEmpty()) {
            return false;
        }
        long diferencia = Math.abs(Instant.now().getEpochSecond() - timestamp);
        if (diferencia > TOLERANCIA_FIRMA_SEG) {
            log.warn("Notificacion de Stripe fuera de la tolerancia de tiempo ({} s)", diferencia);
            return false;
        }
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(webhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            String esperado = HexFormat.of().formatHex(
                    mac.doFinal((timestamp + "." + payload).getBytes(StandardCharsets.UTF_8)));
            for (String firma : firmas) {
                if (MessageDigest.isEqual(esperado.getBytes(StandardCharsets.UTF_8),
                        firma.getBytes(StandardCharsets.UTF_8))) {
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            log.error("No se pudo calcular la firma de Stripe: {}", e.getMessage());
            return false;
        }
    }

    /** Convierte el monto a la unidad menor de la moneda (centavos). */
    private long aCentavos(BigDecimal monto, String moneda) {
        BigDecimal valor = monto == null ? BigDecimal.ZERO : monto;
        int decimales = decimalesMoneda(moneda);
        return valor.setScale(decimales, RoundingMode.HALF_UP)
                .movePointRight(decimales).longValueExact();
    }

    /** Monedas sin parte decimal en Stripe (yen, Won...). */
    private int decimalesMoneda(String moneda) {
        return switch (moneda == null ? "" : moneda.toLowerCase()) {
            case "bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga", "pyg", "rwf",
                 "ugx", "vnd", "vuv", "xaf", "xof", "xpf" -> 0;
            default -> 2;
        };
    }

    private HttpResponse<String> enviar(String metodo, String ruta, List<String> params)
            throws IOException, InterruptedException {
        HttpRequest.Builder builder = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + ruta))
                .header("Authorization", "Bearer " + secretKey)
                .timeout(Duration.ofSeconds(30));
        if ("GET".equals(metodo)) {
            builder.GET();
        } else {
            builder.header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(String.join("&", params),
                            StandardCharsets.UTF_8));
        }
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private static String url(String valor) {
        return valor == null ? "" : URLEncoder.encode(valor, StandardCharsets.UTF_8);
    }

    private static String recortar(String texto) {
        if (texto == null) {
            return "";
        }
        return texto.length() > 300 ? texto.substring(0, 300) : texto;
    }
}
