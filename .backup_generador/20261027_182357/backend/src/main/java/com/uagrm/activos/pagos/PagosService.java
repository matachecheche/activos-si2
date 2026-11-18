package com.uagrm.activos.pagos;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.model.EstadoPago;
import com.uagrm.activos.model.Pago;
import com.uagrm.activos.model.Plan;
import com.uagrm.activos.model.Suscripcion;
import com.uagrm.activos.repository.PagoRepository;
import com.uagrm.activos.repository.PlanRepository;
import com.uagrm.activos.repository.SuscripcionRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Sprint 3: pasarela de pagos REAL.
 *
 * Flujo:
 *  1. La empresa pide un checkout -> se crea un pago PENDIENTE y se llama a
 *     la API del proveedor (Mercado Pago o PayPal) para obtener la URL de pago.
 *  2. El usuario paga en el sitio del proveedor.
 *  3. El proveedor notifica al backend (webhook). El backend NO confía en la
 *     notificacion: consulta el pago en la API del proveedor y solo entonces
 *     lo aprueba y extiende la suscripcion.
 *
 * Si el proveedor no esta configurado, el sistema lo dice claramente y NO
 * simula el pago (salvo que se habilite explicitamente el modo sandbox con
 * APP_PAGOS_SANDBOX=true, pensado solo para demostraciones sin credenciales).
 */
@Service
public class PagosService {

    private static final Logger log = LoggerFactory.getLogger(PagosService.class);

    private final List<ProveedorPagos> proveedores;
    private final ProveedorPagos proveedorActivo;
    private final PagoRepository pagoRepository;
    private final PlanRepository planRepository;
    private final SuscripcionRepository suscripcionRepository;
    private final ActivadorPagos activadorPagos;
    private final AuditoriaService auditoriaService;
    private final boolean sandbox;
    private final String moneda;
    private final BigDecimal factorConversion;
    private final String urlPublica;

    public PagosService(List<ProveedorPagos> proveedores,
                        @Value("${app.pagos.proveedor:MERCADO_PAGO}") String nombreProveedor,
                        @Value("${app.pagos.sandbox:false}") boolean sandbox,
                        @Value("${app.pagos.moneda:BOB}") String moneda,
                        @Value("${app.pagos.factor-conversion:1}") BigDecimal factorConversion,
                        @Value("${app.url-publica:http://localhost:8080}") String urlPublica,
                        PagoRepository pagoRepository, PlanRepository planRepository,
                        SuscripcionRepository suscripcionRepository,
                        ActivadorPagos activadorPagos, AuditoriaService auditoriaService) {
        this.proveedores = proveedores;
        this.proveedorActivo = elegir(nombreProveedor);
        this.sandbox = sandbox;
        this.moneda = moneda == null || moneda.isBlank() ? "BOB" : moneda.trim().toUpperCase();
        this.factorConversion = factorConversion == null || factorConversion.signum() <= 0
                ? BigDecimal.ONE : factorConversion;
        this.urlPublica = urlPublica == null ? "" : urlPublica.replaceAll("/+$", "");
        this.pagoRepository = pagoRepository;
        this.planRepository = planRepository;
        this.suscripcionRepository = suscripcionRepository;
        this.activadorPagos = activadorPagos;
        this.auditoriaService = auditoriaService;
    }

    private ProveedorPagos elegir(String nombre) {
        String buscado = nombre == null ? "" : nombre.trim().toUpperCase();
        for (ProveedorPagos p : proveedores) {
            if (p.nombre().equalsIgnoreCase(buscado)) {
                return p;
            }
        }
        return proveedores.isEmpty() ? null : proveedores.get(0);
    }

    /** Nombre del proveedor configurado (MERCADO_PAGO, PAYPAL... ). */
    public String nombreProveedorActivo() {
        return proveedorActivo == null ? "MERCADO_PAGO" : proveedorActivo.nombre();
    }

    /** Estado de la pasarela: si esta configurada, que proveedor y en que moneda. */
    public Map<String, Object> estado() {
        Map<String, Object> vista = new LinkedHashMap<>();
        boolean configurado = proveedorActivo != null && proveedorActivo.configurado();
        vista.put("proveedor", proveedorActivo == null ? null : proveedorActivo.nombre());
        vista.put("nombreProveedor", proveedorActivo == null ? null : proveedorActivo.nombreVisible());
        vista.put("configurado", configurado);
        vista.put("moneda", moneda);
        vista.put("sandbox", sandbox);
        vista.put("webhookUrl", urlPublica + "/api/pagos/webhook");
        vista.put("proveedoresDisponibles", proveedores.stream().map(p -> Map.of(
                "nombre", p.nombre(),
                "nombreVisible", p.nombreVisible(),
                "configurado", p.configurado())).toList());
        vista.put("mensaje", configurado
                ? "Pagos reales habilitados con " + proveedorActivo.nombreVisible() + "."
                : (sandbox
                    ? "MODO DEMOSTRACION: los pagos se aprueban sin pasar por la pasarela real. "
                      + "Configura las credenciales para cobrar de verdad."
                    : "Pasarela de pagos no configurada. Define " + credencialEsperada()
                      + " en el entorno del servidor para cobrar de verdad."));
        return vista;
    }

    private String credencialEsperada() {
        if (proveedorActivo == null) {
            return "APP_PAGOS_PROVEEDOR";
        }
        return switch (proveedorActivo.nombre()) {
            case "PAYPAL" -> "PAYPAL_CLIENT_ID y PAYPAL_CLIENT_SECRET";
            default -> "MERCADOPAGO_ACCESS_TOKEN";
        };
    }

    /**
     * Crea el checkout real para un plan. Devuelve la URL donde el usuario
     * paga y la referencia interna del pago.
     */
    @Transactional
    public Map<String, Object> crearCheckout(Long planId, int meses, String correo) {
        if (planId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indique el plan");
        }
        if (meses < 1 || meses > 24) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El periodo debe estar entre 1 y 24 meses");
        }
        Plan plan = planRepository.findById(planId).filter(Plan::isActivo)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "El plan no existe"));
        if (proveedorActivo == null || !proveedorActivo.configurado()) {
            if (!sandbox) {
                throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                        "La pasarela de pagos no esta configurada. " + estado().get("mensaje"));
            }
            return sandboxSinPasarela(plan, meses);
        }
        BigDecimal monto = plan.getPrecioMensual().multiply(BigDecimal.valueOf(meses));
        String referencia = generarReferencia();
        BigDecimal montoPasarela = monto.multiply(factorConversion).setScale(2, RoundingMode.HALF_UP);

        ProveedorPagos.SolicitudCheckout solicitud = new ProveedorPagos.SolicitudCheckout(
                referencia,
                "Suscripcion " + plan.getNombre() + " - " + meses + " mes(es)",
                "Activos Fijos y Presupuestos - " + plan.getNombre(),
                montoPasarela,
                correo,
                moneda,
                urlPublica + "/suscripcion?pago=" + referencia,
                urlPublica + "/suscripcion?pago=" + referencia + "&estado=fallido",
                urlPublica + "/suscripcion?pago=" + referencia + "&estado=pendiente",
                urlPublica + "/api/pagos/webhook");

        ProveedorPagos.CheckoutPago checkout = proveedorActivo.crearCheckout(solicitud);

        Pago pago = pagoRepository.save(Pago.builder()
                .suscripcion(suscripcionActual())
                .monto(monto)
                .metodo(proveedorActivo.nombre())
                .proveedor(proveedorActivo.nombre())
                .checkoutId(checkout.checkoutId())
                .referencia(referencia)
                .estado(EstadoPago.PENDIENTE)
                .detalle(detalle(plan, meses, checkout.checkoutId(), montoPasarela))
                .fecha(LocalDateTime.now())
                .build());

        auditoriaService.registrar("PAGO_CREADO", "PAGO", String.valueOf(pago.getId()),
                "Checkout " + proveedorActivo.nombre() + " referencia " + referencia);

        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("pagoId", pago.getId());
        vista.put("referencia", referencia);
        vista.put("estado", pago.getEstado().name());
        vista.put("checkoutUrl", checkout.urlPago());
        vista.put("checkoutId", checkout.checkoutId());
        vista.put("proveedor", proveedorActivo.nombre());
        vista.put("nombreProveedor", proveedorActivo.nombreVisible());
        vista.put("moneda", moneda);
        vista.put("monto", monto);
        vista.put("montoPasarela", montoPasarela);
        vista.put("mensaje", "Paga en " + proveedorActivo.nombreVisible() + " para activar la suscripcion.");
        return vista;
    }


    /**
     * Procesa la notificacion del proveedor: verifica el pago contra la API
     * del proveedor y, si esta aprobado, extiende la suscripcion.
     */
    @Transactional
    public Map<String, Object> procesarNotificacion(String nombreProveedor, String cuerpo,
                                                    Map<String, String> cabeceras) {
        ProveedorPagos proveedor = proveedorPorNombre(nombreProveedor);
        if (proveedor == null || !proveedor.configurado()) {
            log.warn("Notificacion de pago de un proveedor no configurado: {}", nombreProveedor);
            return Map.of("procesado", false, "mensaje", "Proveedor no configurado");
        }
        ProveedorPagos.ResultadoPago resultado = proveedor.confirmarNotificacion(cuerpo, cabeceras);
        if (resultado.referencia() == null || resultado.referencia().isBlank()) {
            return Map.of("procesado", false, "mensaje",
                    resultado.mensaje() == null ? "Notificacion sin referencia" : resultado.mensaje());
        }
        Pago pago = pagoRepository.findByReferencia(resultado.referencia()).orElse(null);
        if (pago == null) {
            log.warn("Pago no encontrado para la referencia {}", resultado.referencia());
            return Map.of("procesado", false, "mensaje", "Pago no encontrado");
        }
        if (pago.getEstado() == EstadoPago.APROBADO) {
            return Map.of("procesado", true, "estado", "APROBADO", "mensaje", "El pago ya estaba aprobado");
        }
        if (resultado.aprobado()) {
            Integer meses = leerMeses(pago.getDetalle());
            activadorPagos.activar(pago, meses == null ? 1 : meses);
            return Map.of("procesado", true, "estado", "APROBADO", "pagoId", pago.getId(),
                    "referencia", pago.getReferencia(),
                    "mensaje", "Pago aprobado y suscripcion activada");
        }
        if (resultado.rechazo()) {
            pago.setEstado(EstadoPago.RECHAZADO);
            pago.setDetalle(combinarDetalle(pago.getDetalle(), resultado.detalle()));
            pagoRepository.save(pago);
            return Map.of("procesado", true, "estado", "RECHAZADO", "mensaje",
                    resultado.mensaje() == null ? "Pago rechazado" : resultado.mensaje());
        }
        return Map.of("procesado", true, "estado", "PENDIENTE", "mensaje",
                resultado.mensaje() == null ? "El pago sigue pendiente" : resultado.mensaje());
    }

    /** Estado de un pago por su referencia (para consultar desde la app). */
    @Transactional(readOnly = true)
    public Map<String, Object> consultarPago(String referencia) {
        return pagoRepository.findByReferencia(referencia)
                .map(p -> {
                    Map<String, Object> vista = new LinkedHashMap<>();
                    vista.put("referencia", p.getReferencia());
                    vista.put("estado", p.getEstado().name());
                    vista.put("monto", p.getMonto());
                    vista.put("metodo", p.getMetodo());
                    vista.put("proveedor", p.getProveedor());
                    vista.put("fecha", p.getFecha());
                    vista.put("fechaAprobacion", p.getFechaAprobacion());
                    return vista;
                })
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Pago no encontrado"));
    }

    // ------------------------------------------------------------------ apoyo

    private ProveedorPagos proveedorPorNombre(String nombre) {
        if (nombre == null || nombre.isBlank()) {
            return proveedorActivo;
        }
        for (ProveedorPagos p : proveedores) {
            if (p.nombre().equalsIgnoreCase(nombre.trim())) {
                return p;
            }
        }
        return proveedorActivo;
    }

    /** Suscripcion de la empresa del contexto (la que se renueva). */
    private Suscripcion suscripcionActual() {
        Long empresaId = TenantContext.getEmpresaId();
        if (empresaId == null) {
            return null;
        }
        return suscripcionRepository.findByEmpresaId(empresaId).orElse(null);
    }

    private String generarReferencia() {
        return "PAG-" + System.currentTimeMillis() + "-" + Integer.toHexString((int) (Math.random() * 0xFFFFFF)).toUpperCase();
    }

    private String detalle(Plan plan, int meses, String checkoutId, BigDecimal montoPasarela) {
        return "{\"planId\":" + plan.getId() + ",\"meses\":" + meses
                + ",\"checkoutId\":\"" + checkoutId + "\""
                + ",\"montoPasarela\":" + montoPasarela.toPlainString() + "}";
    }

    private Integer leerMeses(String detalleJson) {
        if (detalleJson == null) {
            return null;
        }
        try {
            var json = new com.fasterxml.jackson.databind.ObjectMapper().readTree(detalleJson);
            return json.has("meses") ? json.get("meses").asInt() : null;
        } catch (Exception e) {
            return null;
        }
    }

    private String combinarDetalle(String original, String nuevo) {
        String base = original == null || original.isBlank() ? "{}" : original;
        if (nuevo == null || nuevo.isBlank()) {
            return base;
        }
        return base.substring(0, base.length() - 1) + ",\"proveedor\":" + nuevo + "}";
    }

    /**
     * Modo demostracion (APP_PAGOS_SANDBOX=true): se registra el pago y se
     * aprueba en el acto, sin llamar a ninguna pasarela. La interfaz lo
     * avisa bien para que nadie lo confunda con un cobro real.
     */
    private Map<String, Object> sandboxSinPasarela(Plan plan, int meses) {
        BigDecimal monto = plan.getPrecioMensual().multiply(BigDecimal.valueOf(meses));
        String referencia = generarReferencia();
        Suscripcion suscripcion = suscripcionActual();
        Pago pago = pagoRepository.save(Pago.builder()
                .suscripcion(suscripcion)
                .monto(monto)
                .metodo("SANDBOX")
                .proveedor("SANDBOX")
                .referencia(referencia)
                .estado(EstadoPago.PENDIENTE)
                .detalle(detalle(plan, meses, "SANDBOX", monto))
                .fecha(LocalDateTime.now())
                .build());
        if (suscripcion != null) {
            activadorPagos.activar(pago, meses);
        }
        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("pagoId", pago.getId());
        vista.put("referencia", referencia);
        vista.put("estado", EstadoPago.APROBADO.name());
        vista.put("checkoutUrl", null);
        vista.put("proveedor", "SANDBOX");
        vista.put("meses", meses);
        vista.put("monto", monto);
        vista.put("sandbox", true);
        vista.put("mensaje", "MODO DEMOSTRACION: no hay pasarela configurada, el pago se aprueba sin cobrar.");
        return vista;
    }
}
