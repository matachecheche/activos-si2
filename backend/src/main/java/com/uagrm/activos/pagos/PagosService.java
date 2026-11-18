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
import java.util.ArrayList;
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
                "moneda", p.moneda(),
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
        return credencialEsperada(proveedorActivo);
    }

    /** Credenciales que necesita cada pasarela para cobrar de verdad. */
    private String credencialEsperada(ProveedorPagos proveedor) {
        if (proveedor == null) {
            return "APP_PAGOS_PROVEEDOR";
        }
        return switch (proveedor.nombre()) {
            case "PAYPAL" -> "PAYPAL_CLIENT_ID y PAYPAL_CLIENT_SECRET";
            case "STRIPE" -> "STRIPE_SECRET_KEY (y STRIPE_WEBHOOK_SECRET para el webhook)";
            case "QR" -> "APP_PAGOS_QR_CLIENT_ID, APP_PAGOS_QR_CLIENT_SECRET "
                    + "y APP_PAGOS_QR_ID_ESTABLECIMIENTO";
            default -> "MERCADOPAGO_ACCESS_TOKEN";
        };
    }

    /**
     * Crea el checkout real para un plan. Devuelve la URL donde el usuario
     * paga y la referencia interna del pago.
     *
     * @param proveedorNombre proveedor pedido por el usuario (STRIPE, QR...);
     *                        si viene vacio se usa el configurado en el servidor.
     */
    @Transactional
    public Map<String, Object> crearCheckout(Long planId, int meses, String correo) {
        return crearCheckout(planId, meses, correo, null);
    }

    @Transactional
    public Map<String, Object> crearCheckout(Long planId, int meses, String correo, String proveedorNombre) {
        return crearCheckout(planId, meses, correo, proveedorNombre, null);
    }

    /**
     * Crea el checkout para una empresa concreta (registro publico o alta de
     * empresa desde una cuenta ya autenticada). En esos flujos todavia no hay
     * contexto de empresa en el hilo, asi que la suscripcion se recibe
     * explicitamente.
     */
    @Transactional
    public Map<String, Object> crearCheckoutParaEmpresa(Long empresaId, Long planId, int meses,
                                                        String correo, String proveedorNombre) {
        Suscripcion suscripcion = empresaId == null ? null
                : suscripcionRepository.findByEmpresaId(empresaId).orElse(null);
        return crearCheckout(planId, meses, correo, proveedorNombre, suscripcion);
    }

    private Map<String, Object> crearCheckout(Long planId, int meses, String correo,
                                               String proveedorNombre, Suscripcion suscripcion) {
        if (planId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indique el plan");
        }
        if (meses < 1 || meses > 24) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El periodo debe estar entre 1 y 24 meses");
        }
        Plan plan = planRepository.findById(planId).filter(Plan::isActivo)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "El plan no existe"));
        ProveedorPagos proveedor = elegirProveedor(proveedorNombre);
        if (proveedor == null || !proveedor.configurado()) {
            if (!sandbox) {
                String cual = proveedor == null ? "de pagos" : proveedor.nombreVisible();
                throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                        "La pasarela " + cual + " no esta configurada. "
                                + (proveedor == null
                                    ? "Define APP_PAGOS_PROVEEDOR en el entorno del servidor."
                                    : "Define " + credencialEsperada(proveedor)
                                      + " en el entorno del servidor."));
            }
            return sandboxSinPasarela(plan, meses);
        }
        BigDecimal monto = plan.getPrecioMensual().multiply(BigDecimal.valueOf(meses));
        String referencia = generarReferencia();
        String monedaProveedor = proveedor.moneda() == null || proveedor.moneda().isBlank()
                ? moneda : proveedor.moneda();
        BigDecimal factor = proveedor.factorConversion(factorConversion);
        BigDecimal montoPasarela = monto.multiply(factor).setScale(2, RoundingMode.HALF_UP);

        ProveedorPagos.SolicitudCheckout solicitud = new ProveedorPagos.SolicitudCheckout(
                referencia,
                "Suscripcion " + plan.getNombre() + " - " + meses + " mes(es)",
                "Activos Fijos y Presupuestos - " + plan.getNombre(),
                montoPasarela,
                correo,
                monedaProveedor,
                urlPublica + "/suscripcion?pago=" + referencia,
                urlPublica + "/suscripcion?pago=" + referencia + "&estado=fallido",
                urlPublica + "/suscripcion?pago=" + referencia + "&estado=pendiente",
                urlPublica + "/api/pagos/webhook");

        ProveedorPagos.CheckoutPago checkout;
        try {
            checkout = proveedor.crearCheckout(solicitud);
        } catch (RuntimeException e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "La pasarela " + proveedor.nombreVisible() + " no pudo crear el cobro: " + e.getMessage());
        }

        Suscripcion suscripcionPago = suscripcion != null ? suscripcion : suscripcionActual();
        Pago pago = pagoRepository.save(Pago.builder()
                .suscripcion(suscripcionPago)
                .monto(monto)
                .metodo(proveedor.nombre())
                .proveedor(proveedor.nombre())
                .checkoutId(checkout.checkoutId())
                .referencia(referencia)
                .estado(EstadoPago.PENDIENTE)
                .detalle(detalle(plan, meses, checkout.checkoutId(), montoPasarela, checkout.datosBancarios()))
                .fecha(LocalDateTime.now())
                .build());

        auditoriaService.registrar("PAGO_CREADO", "PAGO", String.valueOf(pago.getId()),
                "Checkout " + proveedor.nombre() + " referencia " + referencia);

        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("pagoId", pago.getId());
        vista.put("referencia", referencia);
        vista.put("estado", pago.getEstado().name());
        vista.put("checkoutUrl", checkout.urlPago());
        vista.put("checkoutId", checkout.checkoutId());
        vista.put("proveedor", proveedor.nombre());
        vista.put("nombreProveedor", proveedor.nombreVisible());
        vista.put("moneda", monedaProveedor);
        vista.put("monto", monto);
        vista.put("montoPasarela", montoPasarela);
        if (checkout.datosBancarios() != null && !checkout.datosBancarios().isEmpty()) {
            // Transferencia bancaria: se muestran los datos para depositar.
            vista.put("esTransferencia", true);
            vista.put("datosBancarios", checkout.datosBancarios());
            vista.put("instrucciones", checkout.datosBancarios().getOrDefault("instrucciones",
                    "Transfiere el monto indicado usando el codigo de referencia. "
                            + "La suscripcion se activa cuando el administrador confirme el deposito."));
            vista.put("mensaje", "Transfiere a la cuenta indicada usando la referencia "
                    + referencia + ". La suscripcion se activa al confirmarse el deposito.");
        } else {
            vista.put("esTransferencia", false);
        }
        if (checkout.qrImagenBase64() != null && !checkout.qrImagenBase64().isBlank()) {
            // Proveedor QR: la app muestra el codigo y espera la confirmacion.
            vista.put("qrImagen", "data:image/png;base64," + checkout.qrImagenBase64());
            vista.put("esQr", true);
            vista.put("mensaje", "Escanea el codigo QR con la app de tu banco para pagar en "
                    + proveedor.nombreVisible() + ".");
        } else {
            vista.put("esQr", false);
            vista.put("mensaje", "Paga en " + proveedor.nombreVisible() + " para activar la suscripcion.");
        }
        return vista;
    }

    /**
     * Elige el proveedor pedido por el usuario. Si no existe (o no se pide
     * ninguno) se usa el que esta activo en el servidor. El proveedor pedido
     * se devuelve aunque no tenga credenciales, para poder avisar con
     * precision de que credencial falta.
     */
    private ProveedorPagos elegirProveedor(String nombre) {
        if (nombre != null && !nombre.isBlank()) {
            for (ProveedorPagos p : proveedores) {
                if (p.nombre().equalsIgnoreCase(nombre.trim())) {
                    return p;
                }
            }
        }
        return proveedorActivo;
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
        if (pago == null && resultado.checkoutId() != null && !resultado.checkoutId().isBlank()) {
            // QR Simple notifica con su propio numero de referencia: se busca
            // el pago por el identificador del checkout en la pasarela.
            pago = pagoRepository.findByCheckoutId(resultado.checkoutId()).orElse(null);
        }
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

    /**
     * Metodos de pago disponibles (publico: se usa en el alta de empresa, que
     * se puede hacer sin iniciar sesion). Cada metodo indica si esta
     * configurado de verdad, para que la interfaz no ofrezca un cobro que no
     * se puede hacer.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> metodosDisponibles() {
        List<Map<String, Object>> lista = new ArrayList<>();
        for (ProveedorPagos p : proveedores) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("nombre", p.nombre());
            item.put("nombreVisible", p.nombreVisible());
            item.put("configurado", p.configurado());
            item.put("moneda", p.moneda() == null ? moneda : p.moneda());
            item.put("credencial", credencialEsperada(p));
            item.put("mensaje", p.configurado()
                    ? p.nombreVisible() + " disponible."
                    : "Faltan credenciales (" + credencialEsperada(p) + ") en el servidor.");
            lista.add(item);
        }
        return lista;
    }

    /**
     * Estado publico de un pago (para quien registro la empresa y todavia no
     * inicia sesion). Solo devuelve el estado y el monto: ningun dato de la
     * empresa ni de la cuenta.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> estadoPublicoPago(String referencia) {
        Pago pago = pagoRepository.findByReferencia(referencia)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Pago no encontrado"));
        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("referencia", pago.getReferencia());
        vista.put("estado", pago.getEstado().name());
        vista.put("monto", pago.getMonto());
        vista.put("proveedor", pago.getProveedor());
        vista.put("fecha", pago.getFecha());
        vista.put("fechaAprobacion", pago.getFechaAprobacion());
        vista.put("mensaje", pago.getEstado() == EstadoPago.APROBADO
                ? "Pago confirmado: la suscripcion ya esta activa."
                : "El pago sigue pendiente de confirmacion.");
        return vista;
    }

    // ------------------------------------------------------- transferencia

    /**
     * Transferencias bancarias pendientes de confirmar. Las usa el
     * administrador de la plataforma para conciliar los depositos.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> transferenciasPendientes() {
        List<Map<String, Object>> lista = new ArrayList<>();
        for (Pago pago : pagoRepository.findAllByOrderByFechaDesc()) {
            if (!"TRANSFERENCIA".equalsIgnoreCase(pago.getProveedor())) {
                continue;
            }
            lista.add(vistaTransferencia(pago));
        }
        return lista;
    }

    /** Datos de una transferencia (con los datos bancarios si se guardaron). */
    public Map<String, Object> vistaTransferencia(Pago pago) {
        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("pagoId", pago.getId());
        vista.put("referencia", pago.getReferencia());
        vista.put("estado", pago.getEstado().name());
        vista.put("monto", pago.getMonto());
        vista.put("metodo", pago.getMetodo());
        vista.put("proveedor", pago.getProveedor());
        vista.put("fecha", pago.getFecha());
        vista.put("fechaAprobacion", pago.getFechaAprobacion());
        vista.put("detalle", pago.getDetalle());
        vista.put("empresaId", pago.getSuscripcion() == null || pago.getSuscripcion().getEmpresa() == null
                ? null : pago.getSuscripcion().getEmpresa().getId());
        vista.put("empresa", pago.getSuscripcion() == null || pago.getSuscripcion().getEmpresa() == null
                ? null : pago.getSuscripcion().getEmpresa().getNombre());
        return vista;
    }

    /**
     * Confirma una transferencia bancaria: el administrador verifico el
     * deposito y se activa la suscripcion (igual que con una pasarela en
     * linea, pero el comprobante es el deposito bancario).
     */
    @Transactional
    public Map<String, Object> aprobarTransferencia(String referencia) {
        Pago pago = pagoRepository.findByReferencia(referencia)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Pago no encontrado"));
        if (!"TRANSFERENCIA".equalsIgnoreCase(pago.getProveedor())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Este pago no es una transferencia bancaria");
        }
        if (pago.getEstado() == EstadoPago.APROBADO) {
            return Map.of("aprobado", true, "mensaje", "La transferencia ya estaba aprobada",
                    "referencia", referencia);
        }
        Integer meses = leerMeses(pago.getDetalle());
        activadorPagos.activar(pago, meses == null ? 1 : meses);
        return Map.of("aprobado", true, "referencia", referencia,
                "mensaje", "Transferencia confirmada: la suscripcion quedo activa");
    }

    /** Rechaza una transferencia bancaria (deposito no recibido o monto errado). */
    @Transactional
    public Map<String, Object> rechazarTransferencia(String referencia, String motivo) {
        Pago pago = pagoRepository.findByReferencia(referencia)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Pago no encontrado"));
        if (!"TRANSFERENCIA".equalsIgnoreCase(pago.getProveedor())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Este pago no es una transferencia bancaria");
        }
        if (pago.getEstado() == EstadoPago.APROBADO) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La transferencia ya fue aprobada y no se puede rechazar");
        }
        pago.setEstado(EstadoPago.RECHAZADO);
        pago.setDetalle(combinarDetalle(pago.getDetalle(),
                "\"motivoRechazo\":\"" + (motivo == null ? "" : motivo.replace("\"", "'")) + "\""));
        pagoRepository.save(pago);
        return Map.of("rechazado", true, "referencia", referencia,
                "mensaje", "Transferencia rechazada");
    }

    /**
     * Estado de un pago por su referencia. Si el pago sigue pendiente se
     * consulta a la pasarela (server a server) para saber si ya se pagó.
     */
    @Transactional
    public Map<String, Object> consultarPago(String referencia) {
        Pago pago = pagoRepository.findByReferencia(referencia)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Pago no encontrado"));
        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("referencia", pago.getReferencia());
        vista.put("estado", pago.getEstado().name());
        vista.put("monto", pago.getMonto());
        vista.put("metodo", pago.getMetodo());
        vista.put("proveedor", pago.getProveedor());
        vista.put("fecha", pago.getFecha());
        vista.put("fechaAprobacion", pago.getFechaAprobacion());
        vista.put("verificado", false);
        if (pago.getEstado() == EstadoPago.PENDIENTE) {
            // Consulta en vivo a la pasarela: el webhook puede no haber llegado.
            Map<String, Object> resultado = verificarEnPasarela(pago);
            vista.put("estado", resultado.getOrDefault("estado", pago.getEstado().name()));
            vista.put("verificado", true);
            vista.put("mensaje", resultado.get("mensaje"));
        }
        return vista;
    }

    /** Consulta el pago en la pasarela y, si ya esta pagado, activa la suscripcion. */
    private Map<String, Object> verificarEnPasarela(Pago pago) {
        ProveedorPagos proveedor = proveedorPorNombre(pago.getProveedor());
        if (proveedor == null || !proveedor.configurado() || pago.getCheckoutId() == null) {
            return Map.of("estado", pago.getEstado().name(),
                    "mensaje", "La pasarela no permite consultar este pago");
        }
        try {
            ProveedorPagos.ResultadoPago resultado = proveedor.verificar(pago.getCheckoutId());
            if (resultado.aprobado()) {
                Integer meses = leerMeses(pago.getDetalle());
                activadorPagos.activar(pago, meses == null ? 1 : meses);
                return Map.of("estado", EstadoPago.APROBADO.name(),
                        "mensaje", "Pago confirmado por " + proveedor.nombreVisible());
            }
            if (resultado.rechazo()) {
                pago.setEstado(EstadoPago.RECHAZADO);
                pago.setDetalle(combinarDetalle(pago.getDetalle(), resultado.detalle()));
                pagoRepository.save(pago);
                return Map.of("estado", EstadoPago.RECHAZADO.name(),
                        "mensaje", resultado.mensaje() == null ? "Pago rechazado" : resultado.mensaje());
            }
            return Map.of("estado", EstadoPago.PENDIENTE.name(),
                    "mensaje", resultado.mensaje() == null ? "El pago sigue pendiente" : resultado.mensaje());
        } catch (Exception e) {
            log.warn("No se pudo verificar el pago {} en la pasarela: {}", pago.getReferencia(), e.getMessage());
            return Map.of("estado", pago.getEstado().name(),
                    "mensaje", "No se pudo consultar la pasarela: " + e.getMessage());
        }
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

    private String detalle(Plan plan, int meses, String checkoutId, BigDecimal montoPasarela,
                           Map<String, String> datosBancarios) {
        StringBuilder json = new StringBuilder();
        json.append("{\"planId\":").append(plan.getId())
            .append(",\"meses\":").append(meses)
            .append(",\"checkoutId\":\"").append(checkoutId == null ? "" : checkoutId).append("\"")
            .append(",\"montoPasarela\":").append(montoPasarela.toPlainString());
        if (datosBancarios != null && !datosBancarios.isEmpty()) {
            json.append(",\"datosBancarios\":{");
            boolean primero = true;
            for (Map.Entry<String, String> par : datosBancarios.entrySet()) {
                if (!primero) {
                    json.append(",");
                }
                primero = false;
                json.append("\"").append(par.getKey()).append("\":\"")
                    .append(par.getValue() == null ? "" : par.getValue().replace("\"", "'")).append("\"");
            }
            json.append("}");
        }
        return json.append("}").toString();
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
                .detalle(detalle(plan, meses, "SANDBOX", monto, null))
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
