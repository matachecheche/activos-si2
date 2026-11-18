package com.uagrm.activos.saas;

import com.uagrm.activos.model.EstadoSuscripcion;
import com.uagrm.activos.model.Plan;
import com.uagrm.activos.model.Suscripcion;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.SuscripcionRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * HU-11: aplica los limites del plan contratado (11.8.8). null en el limite
 * significa "ilimitado". Toda operacion que crece la empresa pasa por aqui.
 */
@Service
public class PlanLimitsService {

    private final SuscripcionRepository suscripcionRepository;
    private final UsuarioRepository usuarioRepository;
    private final ActivoRepository activoRepository;

    public PlanLimitsService(SuscripcionRepository suscripcionRepository,
                             UsuarioRepository usuarioRepository,
                             ActivoRepository activoRepository) {
        this.suscripcionRepository = suscripcionRepository;
        this.usuarioRepository = usuarioRepository;
        this.activoRepository = activoRepository;
    }

    /** Suscripcion vigente de la empresa del contexto o error 402/403. */
    public Suscripcion suscripcionVigente() {
        Long empresaId = TenantContext.getEmpresaId();
        if (empresaId == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Sin empresa asociada");
        }
        Suscripcion s = suscripcionRepository.findByEmpresaId(empresaId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.PAYMENT_REQUIRED,
                        "La empresa no tiene una suscripcion"));
        if (s.getEstado() == EstadoSuscripcion.VENCIDA || s.getEstado() == EstadoSuscripcion.CANCELADA) {
            throw new ResponseStatusException(HttpStatus.PAYMENT_REQUIRED,
                    "La suscripcion esta " + s.getEstado() + ": renueve para continuar");
        }
        return s;
    }

    public Plan planVigente() {
        return suscripcionVigente().getPlan();
    }

    public void verificarLimiteUsuarios() {
        Plan plan = planVigente();
        if (plan.getMaxUsuarios() != null) {
            long actuales = usuarioRepository.countByEmpresaId(TenantContext.getEmpresaId());
            if (actuales >= plan.getMaxUsuarios()) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "Limite de " + plan.getMaxUsuarios() + " usuarios del plan " + plan.getNombre()
                                + " alcanzado. Mejore de plan para agregar mas.");
            }
        }
    }

    public void verificarLimiteActivos() {
        Plan plan = planVigente();
        if (plan.getMaxActivos() != null) {
            long actuales = activoRepository.countByEmpresaId(TenantContext.getEmpresaId());
            if (actuales >= plan.getMaxActivos()) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "Limite de " + plan.getMaxActivos() + " activos del plan " + plan.getNombre()
                                + " alcanzado. Mejore de plan.");
            }
        }
    }
}
