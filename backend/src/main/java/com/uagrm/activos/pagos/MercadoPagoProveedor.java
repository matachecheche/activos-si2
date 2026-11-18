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
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Map;

/**
 * Mercado Pago (Checkout Pro) con REST real.
 *
 * - Crea una "preference" y devuelve la URL init_point.
 * - La notificacion (webhook) NO se cree: el backend consulta el pago en la
 *   API de Mercado Pago y solo aprueba si el estado es "approved".
 * - Si hay WEBHOOK_SECRET se valida ademas la firma x-signature.
 */
@Component
public class MercadoPagoProveedor implements ProveedorPagos {

    private static final Logger log = LoggerFactory.getLogger(MercadoPagoProveedor.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final String API = "https://api.mercadopago.com";

    private final String accessToken;
    private final String webhookSecret;
    private final String monedaPorDefecto;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15)).build();

    public MercadoPagoProveedor(
            @Value("${app.pagos.mercadopago.access-token:}") String accessToken,
            @Value("${app.pagos.mercadopago.webhook-secret:}") String webhookSecret,
            @Value("${app.pagos.moneda:BOB}") String monedaPorDefecto) {
        this.accessToken = accessToken == null ? "" : accessToken.trim();
        this.webhookSecret = webhookSecret == null ? "" : webhookSecret.trim();
        this.monedaPorDefecto = monedaPorDefecto == null || monedaPorDefecto.isBlank() ? "BOB" : monedaPorDefecto.trim();
    }

    @Override
    public String nombre() {
        return "MERCADO_PAGO";
    }

    @Override
    public String nombreVisible() {
        return "Mercado Pago";
    }

    @Override
    public boolean configurado() {
        return !accessToken.isBlank();
    }

    @Override
    public String moneda() {
        return monedaPorDefecto;
    }

    @Override
    public CheckoutPago crearCheckout(SolicitudCheckout solicitud) {
        if (!configurado()) {
            throw new IllegalStateException("Mercado Pago no esta configurado (falta MERCADOPAGO_ACCESS_TOKEN)");
        }
        try {
            String cuerpo = """
                    {
                      "items": [{
                        "title": %s,
                        "description": %s,
                        "quantity": 1,
                        "currency_id": %s,
                        "unit_price": %s
                      }],
                      "payer": { "email": %s },
                      "external_reference": %s,
                      "back_urls": {
                        "success": %s,
                        "failure": %s,
                        "pending": %s
                      },
                      "notification_url": %s,
                      "auto_return": "approved",
                      "statement_descriptor": "ACTIVOS FIJOS"
                    }
                    """.formatted(
                    json(solicitud.titulo()), json(solicitud.descripcion()),
                    json(solicitud.moneda()), solicitud.monto().setScale(2, RoundingMode.HALF_UP).toPlainString(),
                    json(solicitud.correo()), json(solicitud.referencia()),
                    json(solicitud.urlExito()), json(solicitud.urlFallo()), json(solicitud.urlPendiente()),
                    json(solicitud.urlWebhook()));

            HttpRequest peticion = HttpRequest.newBuilder()
                    .uri(URI.create(API + "/checkout/preferences"))
                    .header("Authorization", "Bearer " + accessToken)
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(30))
                    .POST(HttpRequest.BodyPublishers.ofString(cuerpo, StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() >= 300) {
                throw new IllegalStateException("Mercado Pago rechazo la preferencia (HTTP "
                        + respuesta.statusCode() + "): " + recortar(respuesta.body()));
            }
            JsonNode json = MAPPER.readTree(respuesta.body());
            String id = json.path("id").asText("");
            String url = json.path("init_point").asText("");
            if (url.isBlank()) {
                url = json.path("sandbox_init_point").asText("");
            }
            if (id.isBlank() || url.isBlank()) {
                throw new IllegalStateException("Mercado Pago no devolvio la URL de pago");
            }
            return new CheckoutPago(id, url, "PENDIENTE");
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo comunicar con Mercado Pago: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La llamada a Mercado Pago fue interrumpida", e);
        }
    }

    @Override
    public ResultadoPago confirmarNotificacion(String cuerpo, Map<String, String> cabeceras) {
        if (!configurado()) {
            return ResultadoPago.sinReferencia("Mercado Pago no esta configurado");
        }
        try {
            JsonNode raiz = MAPPER.readTree(cuerpo == null ? "{}" : cuerpo);
            JsonNode datos = raiz.has("data") ? raiz.path("data") : raiz;
            String idPago = datos.path("id").asText("");
            if (idPago.isBlank()) {
                return ResultadoPago.sinReferencia("Notificacion sin identificador de pago");
            }
            // Firma (si el proveedor la envia y hay secreto configurado).
            if (!webhookSecret.isBlank() && cabeceras != null) {
                String firma = cabeceras.getOrDefault("x-signature", "");
                String hash = cabeceras.getOrDefault("x-hash", "");
                String requestId = cabeceras.getOrDefault("x-request-id", "");
                if (!firma.isBlank() && !validarFirma(idPago, requestId, firma, hash)) {
                    log.warn("Firma de Mercado Pago invalida para el pago {}", idPago);
                    return new ResultadoPago(false, true, null, null, "FIRMA_INVALIDA", null,
                            "Firma de la notificacion invalida");
                }
            }
            // Consulta server to server: la verdad es la API del proveedor.
            HttpRequest peticion = HttpRequest.newBuilder()
                    .uri(URI.create(API + "/v1/payments/" + idPago))
                    .header("Authorization", "Bearer " + accessToken)
                    .timeout(Duration.ofSeconds(30))
                    .GET().build();
            HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() >= 300) {
                return new ResultadoPago(false, false, null, null, "NO_VERIFICADO", null,
                        "Mercado Pago no confirmo el pago (HTTP " + respuesta.statusCode() + ")");
            }
            JsonNode pago = MAPPER.readTree(respuesta.body());
            String estado = pago.path("status").asText("");
            String referencia = pago.path("external_reference").asText("");
            BigDecimal monto = pago.has("transaction_amount")
                    ? new BigDecimal(pago.path("transaction_amount").asText("0")) : null;
            String detalle = MAPPER.writeValueAsString(Map.of(
                    "id", idPago,
                    "estado", estado,
                    "medio", pago.path("payment_method_id").asText(""),
                    "fecha", pago.path("date_approved").asText("")));
            boolean aprobado = "approved".equalsIgnoreCase(estado);
            boolean rechazado = "rejected".equalsIgnoreCase(estado) || "cancelled".equalsIgnoreCase(estado);
            return new ResultadoPago(aprobado, rechazado, referencia, monto, estado, detalle,
                    aprobado ? "Pago aprobado por Mercado Pago" : "El pago sigue en estado " + estado);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo verificar el pago en Mercado Pago: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La verificacion del pago fue interrumpida", e);
        }
    }

    /** Formato de Mercado Pago: sha256("id:{id};request-id:{requestId};{clave}"). */
    private boolean validarFirma(String idPago, String requestId, String firma, String hashRecibido) {
        try {
            String manifiesto = "id:" + idPago + ";request-id:" + requestId + ";" + webhookSecret;
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            String calculado = HexFormat.of().formatHex(md.digest(manifiesto.getBytes(StandardCharsets.UTF_8)));
            if (hashRecibido != null && !hashRecibido.isBlank()) {
                // x-hash es el HMAC-SHA256 del manifiesto con la clave secreta.
                javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
                mac.init(new javax.crypto.spec.SecretKeySpec(webhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
                String hmac = HexFormat.of().formatHex(mac.doFinal(manifiesto.getBytes(StandardCharsets.UTF_8)));
                return hmac.equalsIgnoreCase(hashRecibido) || calculado.equalsIgnoreCase(firma);
            }
            return calculado.equalsIgnoreCase(firma);
        } catch (Exception e) {
            log.warn("No se pudo validar la firma de Mercado Pago: {}", e.getMessage());
            return false;
        }
    }

    /** Escapa un texto para incrustarlo como cadena JSON. */
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
