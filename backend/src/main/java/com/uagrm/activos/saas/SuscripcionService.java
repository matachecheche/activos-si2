package com.uagrm.activos.saas;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.dto.SuscripcionRequest;
import com.uagrm.activos.model.*;
import com.uagrm.activos.pagos.ActivadorPagos;
import com.uagrm.activos.pagos.PagosService;
import com.uagrm.activos.repository.*;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * HU-11: gestion de planes, suscripcion y pagos dentro de una empresa.
 *
 * Sprint 3: la contratacion ya NO se aprueba sola. Se crea un checkout en la
 * pasarela real (Mercado Pago o PayPal) y la suscripcion se extiende cuando
 * el proveedor confirma el pago (webhook verificado contra su API).
 */
@Service
public class SuscripcionService {

    private final SuscripcionRepository suscripcionRepository;
    private final PlanRepository planRepository;
    private final PagoRepository pagoRepository;
    private final EmpresaRepository empresaRepository;
    private final AuditoriaService auditoriaService;
    private final PagosService pagosService;
    private final ActivadorPagos activadorPagos;

    public SuscripcionService(SuscripcionRepository suscripcionRepository, PlanRepository planRepository,
                              PagoRepository pagoRepository, EmpresaRepository empresaRepository,
                              AuditoriaService auditoriaService, PagosService pagosService,
                              ActivadorPagos activadorPagos) {
        this.suscripcionRepository = suscripcionRepository;
        this.planRepository = planRepository;
        this.pagoRepository = pagoRepository;
        this.empresaRepository = empresaRepository;
        this.auditoriaService = auditoriaService;
        this.pagosService = pagosService;
        this.activadorPagos = activadorPagos;
    }

    @Transactional(readOnly = true)
    public List<Plan> listarPlanes() {
        return planRepository.findByActivoTrueOrderByPrecioMensualAsc();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> miSuscripcion() {
        Long empresaId = TenantContext.getEmpresaId();
        Suscripcion s = suscripcionRepository.findByEmpresaId(empresaId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Sin suscripcion"));
        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("suscripcionId", s.getId());
        vista.put("estado", s.getEstado());
        vista.put("fechaInicio", s.getFechaInicio());
        vista.put("fechaVencimiento", s.getFechaVencimiento());
        vista.put("plan", s.getPlan());
        vista.put("empresa", empresaRepository.findById(empresaId).orElse(null));
        vista.put("pagos", pagoRepository.findBySuscripcionEmpresaIdOrderByFechaDesc(empresaId));
        vista.put("pasarela", pagosService.estado());
        return vista;
    }

    /**
     * Compra o renovacion. Crea el checkout en la pasarela real y devuelve la
     * URL de pago. La suscripcion se activa sola cuando el proveedor confirma.
     */
    @Transactional
    public Map<String, Object> contratar(SuscripcionRequest req) {
        Long empresaId = TenantContext.getEmpresaId();
        if (TenantContext.esSuperAdmin()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "El Super Admin de plataforma no contrata suscripciones");
        }
        Plan plan = planRepository.findById(req.getPlanId())
                .filter(Plan::isActivo)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Plan no valido"));
        suscripcionRepository.findByEmpresaId(empresaId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Sin suscripcion"));

        String correo = TenantContext.getCorreo();
        // El metodo de pago elegido por el usuario (MERCADO_PAGO, PAYPAL,
        // STRIPE, QR) decide la pasarela; si no esta configurada se usa la
        // que este activa en el servidor.
        return pagosService.crearCheckout(plan.getId(), req.getMeses(), correo, req.getMetodoPago());
    }

    /**
     * Aprueba un pago y extiende la suscripcion. La logica vive en
     * ActivadorPagos (clase aparte) para no crear un ciclo de beans entre
     * SuscripcionService y PagosService.
     */
    @Transactional
    public void activarPago(Pago pago, int meses) {
        activadorPagos.activar(pago, meses);
    }
}
