package com.uagrm.activos.pagos;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.Map;

/**
 * QR Simple (Red Enlace / ATC) - el codigo QR oficial e interoperable del
 * Banco Central de Bolivia. El cliente escanea el QR desde la app de su
 * banco y el pago se acredita en la red interbancaria.
 *
 * API real (documentacion tecnica de ATC):
 *  - POST {base}oauth-client-credentials/access-token?grant_type=client_credentials
 *      -> access_token (OAuth 2.0 client credentials).
 *  - POST {base}qr/simple/v2/generate   -> genera el QR (imagen PNG en base64).
 *  - GET  {base}qr/simple/v2/verify/{numeroReferencia} -> estado (PENDIENTE,
 *      PAGADO, CANCELADO, EXPIRADO, ERROR).
 *  - POST {base}qr/simple/v2/cancel/{numeroReferencia}.
 *
 * La confirmacion llega por webhook al backend (cabecera con la clave que el
 * propio sistema define) y SIEMPRE se contrasta consultando el estado en la
 * API de ATC: el sistema nunca aprueba un pago por su cuenta.
 */
@Component
public class QrSimpleProveedor implements ProveedorPagos {

    private static final Logger log = LoggerFactory.getLogger(QrSimpleProveedor.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final String clientId;
    private final String clientSecret;
    private final String baseUrl;
    private final String nombreEstablecimiento;
    private final int idEstablecimiento;
    private final int vigenciaSegundos;
    private final String webhookKey;
    private final String webhookValue;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15)).build();

    /** Token de acceso en cache (expira en una hora segun ATC). */
    private String accessToken;
    private long tokenObtenido;

    public QrSimpleProveedor(
            @Value("${app.pagos.qr.client-id:}") String clientId,
            @Value("${app.pagos.qr.client-secret:}") String clientSecret,
            @Value("${app.pagos.qr.base-url:https://atcgwapitest.redenlace.com.bo/sandbox}") String baseUrl,
            @Value("${app.pagos.qr.id-establecimiento:0}") int idEstablecimiento,
            @Value("${app.pagos.qr.nombre-establecimiento:Activos Fijos}") String nombreEstablecimiento,
            @Value("${app.pagos.qr.vigencia:900}") int vigenciaSegundos,
            @Value("${app.pagos.qr.webhook-key:x-api-key}") String webhookKey,
            @Value("${app.pagos.qr.webhook-value:}") String webhookValue) {
        this.clientId = clientId == null ? "" : clientId.trim();
        this.clientSecret = clientSecret == null ? "" : clientSecret.trim();
        this.baseUrl = (baseUrl == null || baseUrl.isBlank()
                ? "https://atcgwapitest.redenlace.com.bo/sandbox" : baseUrl.trim())
                .replaceAll("/+$", "");
        this.idEstablecimiento = idEstablecimiento;
        this.nombreEstablecimiento = nombreEstablecimiento == null || nombreEstablecimiento.isBlank()
                ? "Activos Fijos" : nombreEstablecimiento.trim();
        this.vigenciaSegundos = vigenciaSegundos <= 0 ? 900 : vigenciaSegundos;
        this.webhookKey = webhookKey == null || webhookKey.isBlank() ? "x-api-key" : webhookKey.trim();
        this.webhookValue = webhookValue == null ? "" : webhookValue.trim();
    }

    @Override
    public String nombre() {
        return "QR";
    }

    @Override
    public String nombreVisible() {
        return "QR Simple (Red Enlace)";
    }

    @Override
    public boolean configurado() {
        return !clientId.isBlank() && !clientSecret.isBlank() && idEstablecimiento > 0;
    }

    @Override
    public String moneda() {
        // El QR Simple cobra en bolivianos ( interoperable BCB ).
        return "BOB";
    }

    @Override
    public CheckoutPago crearCheckout(SolicitudCheckout solicitud) {
        if (!configurado()) {
            throw new IllegalStateException("QR Simple no esta configurado (faltan APP_PAGOS_QR_CLIENT_ID, "
                    + "APP_PAGOS_QR_CLIENT_SECRET y APP_PAGOS_QR_ID_ESTABLECIMIENTO)");
        }
        try {
            String token = token();
            String cuerpo = MAPPER.writeValueAsString(Map.of(
                    "glosa", solicitud.titulo() == null ? "Pago de suscripcion" : solicitud.titulo(),
                    "moneda", "BOB",
                    "monto", solicitud.monto() == null ? BigDecimal.ZERO : solicitud.monto(),
                    "numeroReferencia", referenciaValida(solicitud.referencia()),
                    "vigencia", vigenciaSegundos,
                    "idEstablecimiento", idEstablecimiento,
                    "nombreEstablecimiento", nombreEstablecimiento,
                    "webhook", Map.of(
                            "url", solicitud.urlWebhook(),
                            "key", webhookKey,
                            "value", webhookValue.isBlank() ? webhookKey : webhookValue)));

            HttpRequest peticion = HttpRequest.newBuilder()
                    .uri(URI.create(baseUrl + "/qr/simple/v2/generate"))
                    .header("access_token", token)
                    .header("client_id", clientId)
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(30))
                    .POST(HttpRequest.BodyPublishers.ofString(cuerpo, StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() >= 300) {
                throw new IllegalStateException("QR Simple rechazo la generacion del QR (HTTP "
                        + respuesta.statusCode() + "): " + recortar(respuesta.body()));
            }
            JsonNode json = MAPPER.readTree(respuesta.body());
            if (!json.path("success").asBoolean(false)) {
                throw new IllegalStateException("QR Simple no genero el QR: " + json.path("message").asText(""));
            }
            JsonNode data = json.path("data");
            String referenciaAtc = data.path("numeroReferencia").asText("");
            String imagen = data.path("qr").asText("");
            if (referenciaAtc.isBlank() || imagen.isBlank()) {
                throw new IllegalStateException("QR Simple no devolvio el codigo QR");
            }
            // En QR el usuario no navega a una pagina: escanea la imagen.
            return new CheckoutPago(referenciaAtc, null, data.path("estado").asText("PENDIENTE"), imagen);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo comunicar con QR Simple: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La llamada a QR Simple fue interrumpida", e);
        }
    }

    @Override
    public ResultadoPago confirmarNotificacion(String cuerpo, Map<String, String> cabeceras) {
        if (!configurado()) {
            return ResultadoPago.sinReferencia("QR Simple no esta configurado");
        }
        // Seguridad del webhook: la cabecera con la clave que definimos en la
        // generacion del QR debe venir con el valor exacto.
        String recibida = cabeceras == null ? null : cabeceras.get(webhookKey.toLowerCase());
        if (webhookValue.isBlank()) {
            log.warn("APP_PAGOS_QR_WEBHOOK_VALUE no esta definido: no se puede validar la notificacion");
            return ResultadoPago.sinReferencia("Notificacion QR sin credencial de webhook configurada");
        }
        if (recibida == null || !recibida.trim().equals(webhookValue)) {
            log.warn("Notificacion QR con credencial de webhook invalida");
            return ResultadoPago.sinReferencia("Credencial del webhook QR invalida");
        }
        try {
            JsonNode raiz = MAPPER.readTree(cuerpo == null ? "{}" : cuerpo);
            String referenciaAtc = raiz.path("numeroReferencia").asText("");
            if (referenciaAtc.isBlank()) {
                return ResultadoPago.sinReferencia("Notificacion QR sin numeroReferencia");
            }
            // El estado real se consulta en la API de ATC (nunca se cree al aviso).
            ResultadoPago verificado = verificar(referenciaAtc);
            if (verificado.referencia() == null || verificado.referencia().isBlank()) {
                return new ResultadoPago(false, false, null, verificado.monto(), verificado.estadoProveedor(),
                        verificado.detalle(),
                        "La notificacion QR no pudo vincularse con un pago: " + verificado.mensaje(),
                        referenciaAtc);
            }
            return verificado;
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo leer la notificacion QR: " + e.getMessage(), e);
        }
    }

    @Override
    public ResultadoPago verificar(String checkoutId) {
        if (!configurado()) {
            return ResultadoPago.sinReferencia("QR Simple no esta configurado");
        }
        if (checkoutId == null || checkoutId.isBlank()) {
            return ResultadoPago.sinReferencia("Falta el numero de referencia del QR");
        }
        try {
            HttpRequest peticion = HttpRequest.newBuilder()
                    .uri(URI.create(baseUrl + "/qr/simple/v2/verify/" + checkoutId))
                    .header("access_token", token())
                    .header("client_id", clientId)
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(30))
                    .GET().build();
            HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() >= 300) {
                return new ResultadoPago(false, false, null, null, "NO_VERIFICADO", null,
                        "QR Simple no confirmo la transaccion (HTTP " + respuesta.statusCode() + ")", checkoutId);
            }
            JsonNode json = MAPPER.readTree(respuesta.body());
            if (!json.path("success").asBoolean(false)) {
                return new ResultadoPago(false, false, null, null, "NO_VERIFICADO", null,
                        "QR Simple respondio: " + json.path("message").asText(""), checkoutId);
            }
            JsonNode data = json.path("data");
            String estado = data.path("estado").asText("");
            String referencia = data.path("numeroReferenciaOriginante").asText("");
            BigDecimal monto = data.path("importe").isNumber()
                    ? new BigDecimal(data.path("importe").asText()) : null;
            String detalle = MAPPER.writeValueAsString(Map.of(
                    "numeroReferencia", checkoutId,
                    "estado", estado,
                    "mensaje", data.path("mensaje").asText(""),
                    "moneda", data.path("moneda").asText("")));
            boolean aprobado = "PAGADO".equalsIgnoreCase(estado);
            boolean rechazado = "CANCELADO".equalsIgnoreCase(estado)
                    || "EXPIRADO".equalsIgnoreCase(estado)
                    || "ERROR".equalsIgnoreCase(estado);
            return new ResultadoPago(aprobado, rechazado, referencia, monto, estado, detalle,
                    aprobado ? "Pago confirmado por QR Simple"
                            : "El pago QR sigue en estado " + estado, checkoutId);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo verificar el pago en QR Simple: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La verificacion del pago fue interrumpida", e);
        }
    }

    /** OAuth 2.0 client credentials de ATC (el token dura una hora). */
    private String token() throws IOException, InterruptedException {
        long ahora = System.currentTimeMillis();
        if (accessToken != null && !accessToken.isBlank() && ahora - tokenObtenido < 50 * 60 * 1000L) {
            return accessToken;
        }
        String credenciales = Base64.getEncoder().encodeToString(
                (clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));
        HttpRequest peticion = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/oauth-client-credentials/access-token?grant_type=client_credentials"))
                .header("Authorization", "Basic " + credenciales)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .timeout(Duration.ofSeconds(20))
                .POST(HttpRequest.BodyPublishers.ofString("", StandardCharsets.UTF_8))
                .build();
        HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
        if (respuesta.statusCode() >= 300) {
            throw new IllegalStateException("QR Simple rechazo las credenciales (HTTP "
                    + respuesta.statusCode() + "): " + recortar(respuesta.body()));
        }
        String nuevo = MAPPER.readTree(respuesta.body()).path("access_token").asText("");
        if (nuevo.isBlank()) {
            throw new IllegalStateException("QR Simple no devolvio el access_token");
        }
        accessToken = nuevo;
        tokenObtenido = ahora;
        return nuevo;
    }

    /** La referencia del integrador admite letras y numeros (la usa ATC para conciliar). */
    private String referenciaValida(String referencia) {
        if (referencia == null || referencia.isBlank()) {
            return "PAG" + System.currentTimeMillis();
        }
        String limpia = referencia.replaceAll("[^A-Za-z0-9]", "");
        if (limpia.isBlank()) {
            limpia = "PAG" + System.currentTimeMillis();
        }
        return limpia.length() > 30 ? limpia.substring(0, 30) : limpia;
    }

    private static String recortar(String texto) {
        if (texto == null) {
            return "";
        }
        return texto.length() > 300 ? texto.substring(0, 300) : texto;
    }
}
