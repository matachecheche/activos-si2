package com.uagrm.activos.pagos;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.model.EstadoPago;
import com.uagrm.activos.model.EstadoSuscripcion;
import com.uagrm.activos.model.Pago;
import com.uagrm.activos.model.Plan;
import com.uagrm.activos.model.Suscripcion;
import com.uagrm.activos.repository.PagoRepository;
import com.uagrm.activos.repository.PlanRepository;
import com.uagrm.activos.repository.SuscripcionRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * Sprint 3: activa la suscripcion de una empresa cuando su pago queda
 * APROBADO en la pasarela real.
 *
 * Vive en su propia clase (y no dentro de SuscripcionService) para que
 * PagosService y SuscripcionService no se dependan entre si: de lo contrario
 * Spring detecta un ciclo de beans y la aplicacion no arranca.
 */
@Service
public class ActivadorPagos {

    private final SuscripcionRepository suscripcionRepository;
    private final PlanRepository planRepository;
    private final PagoRepository pagoRepository;
    private final AuditoriaService auditoriaService;

    public ActivadorPagos(SuscripcionRepository suscripcionRepository, PlanRepository planRepository,
                          PagoRepository pagoRepository, AuditoriaService auditoriaService) {
        this.suscripcionRepository = suscripcionRepository;
        this.planRepository = planRepository;
        this.pagoRepository = pagoRepository;
        this.auditoriaService = auditoriaService;
    }

    /**
     * Aprueba el pago y extiende (o renueva) la suscripcion de la empresa.
     */
    @Transactional
    public void activar(Pago pago, int meses) {
        Suscripcion s = pago.getSuscripcion();
        if (s == null) {
            Long empresaId = TenantContext.getEmpresaId();
            s = empresaId == null ? null : suscripcionRepository.findByEmpresaId(empresaId).orElse(null);
        }
        if (s == null) {
            return;
        }
        Long planId = leerPlanId(pago.getDetalle());
        Plan plan = planId == null ? s.getPlan() : planRepository.findById(planId).orElse(s.getPlan());
        if (plan == null) {
            return;
        }

        LocalDateTime ahora = LocalDateTime.now();
        boolean esRenovacion = s.getPlan() != null && s.getPlan().getId().equals(plan.getId());
        LocalDateTime vence = s.getFechaVencimiento() != null && s.getFechaVencimiento().isAfter(ahora) && esRenovacion
                ? s.getFechaVencimiento().plusMonths(meses)
                : ahora.plusMonths(meses);

        pago.setEstado(EstadoPago.APROBADO);
        pago.setFechaAprobacion(ahora);
        if ((pago.getProveedor() == null || pago.getProveedor().isBlank()) && pago.getMetodo() != null) {
            pago.setMetodo(pago.getProveedor());
        }
        pagoRepository.save(pago);

        s.setPlan(plan);
        s.setFechaVencimiento(vence);
        s.setEstado(EstadoSuscripcion.ACTIVA);
        s.setFechaEstado(ahora);
        suscripcionRepository.save(s);

        if (s.getEmpresa() != null) {
            TenantContext.setEmpresaId(s.getEmpresa().getId());
        }
        auditoriaService.registrar(esRenovacion ? "RENOVACION" : "CAMBIO_PLAN",
                "SUSCRIPCION", String.valueOf(s.getId()),
                (esRenovacion ? "Renovacion" : "Cambio a plan " + plan.getNombre())
                        + " por " + meses + " mes(es), pago " + pago.getReferencia()
                        + " (" + pago.getProveedor() + ")");
    }

    private Long leerPlanId(String detalleJson) {
        if (detalleJson == null) {
            return null;
        }
        try {
            var json = new com.fasterxml.jackson.databind.ObjectMapper().readTree(detalleJson);
            return json.has("planId") ? json.get("planId").asLong() : null;
        } catch (Exception e) {
            return null;
        }
    }
}
