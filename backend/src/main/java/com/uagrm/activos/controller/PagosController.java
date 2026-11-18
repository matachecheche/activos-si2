package com.uagrm.activos.controller;

import com.uagrm.activos.pagos.PagosService;
import com.uagrm.activos.tenant.TenantContext;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashMap;
import java.util.Map;

/**
 * Sprint 3: pasarela de pagos real.
 *
 * - GET  /api/pagos/estado     -> si la pasarela esta configurada.
 * - POST /api/pagos/checkout   -> crea el checkout y devuelve la URL de pago.
 * - GET  /api/pagos/{ref}      -> estado de un pago.
 * - POST /api/pagos/webhook    -> notificacion del proveedor (sin JWT: la
 *        pasarela no tiene una cuenta del sistema; la seguridad la da la
 *        verificacion server to server contra la API del proveedor).
 */
@RestController
@RequestMapping("/api/pagos")
public class PagosController {

    private static final Logger log = LoggerFactory.getLogger(PagosController.class);

    private final PagosService pagosService;

    public PagosController(PagosService pagosService) {
        this.pagosService = pagosService;
    }

    @GetMapping("/estado")
    @PreAuthorize("hasAuthority('PERM_SUSCRIPCION_LEER') or hasAuthority('PERM_SUSCRIPCION_EDITAR')")
    public Map<String, Object> estado() {
        return pagosService.estado();
    }

    @PostMapping("/checkout")
    @PreAuthorize("hasAuthority('PERM_SUSCRIPCION_EDITAR')")
    public Map<String, Object> checkout(@RequestBody Map<String, Object> cuerpo) {
        Object planId = cuerpo.get("planId");
        if (planId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indique el plan");
        }
        int meses = cuerpo.get("meses") == null ? 1 : Integer.parseInt(cuerpo.get("meses").toString());
        String correo = TenantContext.getCorreo();
        String proveedor = cuerpo.get("proveedor") == null ? null : cuerpo.get("proveedor").toString();
        return pagosService.crearCheckout(Long.valueOf(planId.toString()), meses, correo, proveedor);
    }

    @GetMapping("/{referencia}")
    @PreAuthorize("hasAuthority('PERM_SUSCRIPCION_LEER')")
    public Map<String, Object> consultar(@PathVariable String referencia) {
        return pagosService.consultarPago(referencia);
    }

    /** Webhook del proveedor. Publico: la seguridad la aporta la verificacion. */
    @PostMapping("/webhook")
    public ResponseEntity<Map<String, Object>> webhook(@RequestBody(required = false) String cuerpo,
                                                       HttpServletRequest request) {
        Map<String, String> cabeceras = new HashMap<>();
        java.util.Collections.list(request.getHeaderNames())
                .forEach(nombre -> cabeceras.put(nombre.toLowerCase(), request.getHeader(nombre)));
        // El proveedor se puede indicar con la cabecera x-proveedor; si no, se
        // deduce de la firma que manda cada pasarela y, como ultimo recurso,
        // se usa el proveedor configurado en el servidor.
        String proveedor = cabeceras.getOrDefault("x-proveedor", "").trim();
        if (proveedor.isBlank()) {
            proveedor = deducirProveedor(cabeceras);
        }
        try {
            Map<String, Object> resultado = pagosService.procesarNotificacion(proveedor, cuerpo, cabeceras);
            // QR Simple (Red Enlace) espera esta respuesta para confirmar la recepcion.
            if ("QR".equalsIgnoreCase(proveedor)) {
                Map<String, Object> cuerpoRespuesta = new HashMap<>();
                cuerpoRespuesta.put("codigoRespuesta", "SUCCESS");
                cuerpoRespuesta.put("detalleRespuesta",
                        resultado.getOrDefault("mensaje", "Notificacion recibida").toString());
                cuerpoRespuesta.putAll(resultado);
                return ResponseEntity.ok(cuerpoRespuesta);
            }
            return ResponseEntity.ok(resultado);
        } catch (Exception e) {
            log.error("Error procesando la notificacion de pago ({}): {}", proveedor, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("procesado", false, "mensaje", e.getMessage()));
        }
    }

    /** Deduce el proveedor segun las cabeceras de firma de cada pasarela. */
    private String deducirProveedor(Map<String, String> cabeceras) {
        if (cabeceras.containsKey("stripe-signature")) {
            return "STRIPE";
        }
        if (cabeceras.containsKey("x-api-key") || cabeceras.containsKey("x-qr-api-key")) {
            return "QR";
        }
        return pagosService.nombreProveedorActivo();
    }
}
