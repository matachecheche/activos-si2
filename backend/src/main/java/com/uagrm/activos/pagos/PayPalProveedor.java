package com.uagrm.activos.pagos;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.Map;

/**
 * PayPal (Orders v2) con REST real.
 *
 * - Obtiene un token OAuth2 (client_credentials) y crea una orden.
 * - La notificacion se valida consultando la orden en la API de PayPal:
 *   solo se aprueba si status = COMPLETED (o APPROVED y el capture funciona).
 */
@Component
public class PayPalProveedor implements ProveedorPagos {

    private static final Logger log = LoggerFactory.getLogger(PayPalProveedor.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final String clientId;
    private final String clientSecret;
    private final String ambiente;
    private final String monedaPorDefecto;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15)).build();

    public PayPalProveedor(
            @Value("${app.pagos.paypal.client-id:}") String clientId,
            @Value("${app.pagos.paypal.client-secret:}") String clientSecret,
            @Value("${app.pagos.paypal.ambiente:live}") String ambiente,
            @Value("${app.pagos.moneda:BOB}") String monedaPorDefecto) {
        this.clientId = clientId == null ? "" : clientId.trim();
        this.clientSecret = clientSecret == null ? "" : clientSecret.trim();
        this.ambiente = "sandbox".equalsIgnoreCase(ambiente) ? "sandbox" : "live";
        this.monedaPorDefecto = monedaPorDefecto == null || monedaPorDefecto.isBlank() ? "BOB" : monedaPorDefecto.trim();
    }

    private String base() {
        return "sandbox".equals(ambiente)
                ? "https://api-m.sandbox.paypal.com"
                : "https://api-m.paypal.com";
    }

    @Override
    public String nombre() {
        return "PAYPAL";
    }

    @Override
    public String nombreVisible() {
        return "PayPal";
    }

    @Override
    public boolean configurado() {
        return !clientId.isBlank() && !clientSecret.isBlank();
    }

    @Override
    public String moneda() {
        return monedaPorDefecto;
    }

    @Override
    public CheckoutPago crearCheckout(SolicitudCheckout solicitud) {
        if (!configurado()) {
            throw new IllegalStateException("PayPal no esta configurado (faltan PAYPAL_CLIENT_ID y PAYPAL_CLIENT_SECRET)");
        }
        try {
            String cuerpo = """
                    {
                      "intent": "CAPTURE",
                      "purchase_units": [{
                        "reference_id": %s,
                        "description": %s,
                        "custom_id": %s,
                        "amount": {
                          "currency_code": %s,
                          "value": %s
                        }
                      }],
                      "application_context": {
                        "brand_name": "Activos Fijos",
                        "user_action": "PAY_NOW",
                        "return_url": %s,
                        "cancel_url": %s
                      }
                    }
                    """.formatted(
                    json(solicitud.referencia()), json(solicitud.descripcion()), json(solicitud.referencia()),
                    json(solicitud.moneda()), solicitud.monto().setScale(2, RoundingMode.HALF_UP).toPlainString(),
                    json(solicitud.urlExito()), json(solicitud.urlFallo()));

            HttpRequest peticion = HttpRequest.newBuilder()
                    .uri(URI.create(base() + "/v2/checkout/orders"))
                    .header("Authorization", "Bearer " + token())
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(30))
                    .POST(HttpRequest.BodyPublishers.ofString(cuerpo, StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() >= 300) {
                throw new IllegalStateException("PayPal rechazo la orden (HTTP " + respuesta.statusCode()
                        + "): " + recortar(respuesta.body()));
            }
            JsonNode json = MAPPER.readTree(respuesta.body());
            String id = json.path("id").asText("");
            String url = "";
            for (JsonNode enlace : json.path("links")) {
                if ("approve".equalsIgnoreCase(enlace.path("rel").asText(""))) {
                    url = enlace.path("href").asText("");
                }
            }
            if (id.isBlank() || url.isBlank()) {
                throw new IllegalStateException("PayPal no devolvio la URL de aprobacion");
            }
            return new CheckoutPago(id, url, json.path("status").asText("CREATED"));
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo comunicar con PayPal: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La llamada a PayPal fue interrumpida", e);
        }
    }

    @Override
    public ResultadoPago confirmarNotificacion(String cuerpo, Map<String, String> cabeceras) {
        if (!configurado()) {
            return ResultadoPago.sinReferencia("PayPal no esta configurado");
        }
        try {
            JsonNode raiz = MAPPER.readTree(cuerpo == null ? "{}" : cuerpo);
            String idOrden = "";
            if (raiz.has("resource")) {
                idOrden = raiz.path("resource").path("id").asText("");
            } else if (raiz.has("id")) {
                idOrden = raiz.path("id").asText("");
            }
            if (idOrden.isBlank()) {
                return ResultadoPago.sinReferencia("Notificacion sin identificador de orden");
            }
            HttpRequest peticion = HttpRequest.newBuilder()
                    .uri(URI.create(base() + "/v2/checkout/orders/" + idOrden))
                    .header("Authorization", "Bearer " + token())
                    .timeout(Duration.ofSeconds(30))
                    .GET().build();
            HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() >= 300) {
                return new ResultadoPago(false, false, null, null, "NO_VERIFICADO", null,
                        "PayPal no confirmo la orden (HTTP " + respuesta.statusCode() + ")");
            }
            JsonNode orden = MAPPER.readTree(respuesta.body());
            String estado = orden.path("status").asText("");
            JsonNode unidad = orden.path("purchase_units").path(0);
            String referencia = unidad.path("reference_id").asText("");
            if (referencia.isBlank()) {
                referencia = unidad.path("custom_id").asText("");
            }
            BigDecimal monto = null;
            String valor = unidad.path("amount").path("value").asText("");
            if (!valor.isBlank()) {
                monto = new BigDecimal(valor);
            }
            String detalle = MAPPER.writeValueAsString(Map.of(
                    "id", idOrden,
                    "estado", estado,
                    "moneda", unidad.path("amount").path("currency_code").asText("")));
            boolean aprobado = "COMPLETED".equalsIgnoreCase(estado);
            boolean rechazado = "DECLINED".equalsIgnoreCase(estado) || "VOIDED".equalsIgnoreCase(estado);
            return new ResultadoPago(aprobado, rechazado, referencia, monto, estado, detalle,
                    aprobado ? "Pago aprobado por PayPal" : "El pago sigue en estado " + estado);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo verificar el pago en PayPal: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La verificacion del pago fue interrumpida", e);
        }
    }

    /** Token OAuth2 client_credentials (se pide en cada llamada: es de vida corta). */
    private String token() throws IOException, InterruptedException {
        String credenciales = Base64.getEncoder().encodeToString(
                (clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));
        String cuerpo = "grant_type=client_credentials";
        HttpRequest peticion = HttpRequest.newBuilder()
                .uri(URI.create(base() + "/v1/oauth2/token"))
                .header("Authorization", "Basic " + credenciales)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .timeout(Duration.ofSeconds(20))
                .POST(HttpRequest.BodyPublishers.ofString(cuerpo, StandardCharsets.UTF_8))
                .build();
        HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
        if (respuesta.statusCode() >= 300) {
            throw new IllegalStateException("PayPal rechazo las credenciales (HTTP " + respuesta.statusCode() + ")");
        }
        return MAPPER.readTree(respuesta.body()).path("access_token").asText("");
    }

    private static String json(String valor) {
        if (valor == null) {
            return "\"\"";
        }
        StringBuilder sb = new StringBuilder("\"");
        for (char c : valor.toCharArray()) {
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.append('"').toString();
    }

    private static String recortar(String texto) {
        if (texto == null) {
            return "";
        }
        return texto.length() > 300 ? texto.substring(0, 300) : texto;
    }
}
