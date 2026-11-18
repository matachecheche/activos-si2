package com.uagrm.activos.saas;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.model.*;
import com.uagrm.activos.repository.*;
import com.uagrm.activos.tenant.TenantContext;
import com.uagrm.activos.tenant.TenantResolver;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * HU-12: operaciones del Super Admin de plataforma sobre las empresas
 * (suspender, cancelar, reactivar) y metricas globales del SaaS.
 */
@Service
public class EmpresaAdminService {

    private final EmpresaRepository empresaRepository;
    private final SuscripcionRepository suscripcionRepository;
    private final UsuarioRepository usuarioRepository;
    private final ActivoRepository activoRepository;
    private final AuditoriaService auditoriaService;

    public EmpresaAdminService(EmpresaRepository empresaRepository,
                               SuscripcionRepository suscripcionRepository,
                               UsuarioRepository usuarioRepository,
                               ActivoRepository activoRepository,
                               AuditoriaService auditoriaService) {
        this.empresaRepository = empresaRepository;
        this.suscripcionRepository = suscripcionRepository;
        this.usuarioRepository = usuarioRepository;
        this.activoRepository = activoRepository;
        this.auditoriaService = auditoriaService;
    }

    /**
     * Empresas reales del SaaS. Se excluye la empresa centinela id 0
     * (TenantResolver.ROOT / "Plataforma SaaS"), que solo da soporte a las
     * filas del Super Admin y no es una empresa cliente.
     */
    private List<Empresa> empresasClientes() {
        return empresaRepository.findAll().stream()
                .filter(e -> e.getId() != null && e.getId() > 0)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Empresa> listarEmpresas() {
        exigirSuperAdmin();
        return empresasClientes();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> metricasPlataforma() {
        exigirSuperAdmin();
        List<Empresa> clientes = empresasClientes();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("totalEmpresas", clientes.size());
        m.put("empresasActivas", clientes.stream()
                .filter(e -> e.getEstado() == EstadoEmpresa.ACTIVA).count());
        m.put("suscripcionesActivas", suscripcionRepository.findAll().stream()
                .filter(s -> s.getEstado() == EstadoSuscripcion.ACTIVA).count());
        return m;
    }

    @Transactional
    public Empresa cambiarEstado(Long empresaId, EstadoEmpresa nuevoEstado) {
        exigirSuperAdmin();
        if (empresaId == null || empresaId <= TenantResolver.ROOT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La empresa de plataforma no se puede suspender ni cancelar");
        }
        Empresa empresa = empresaRepository.findById(empresaId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Empresa no encontrada"));
        EstadoEmpresa anterior = empresa.getEstado();
        empresa.setEstado(nuevoEstado);
        empresaRepository.save(empresa);

        suscripcionRepository.findByEmpresaId(empresaId).ifPresent(s -> {
            if (nuevoEstado == EstadoEmpresa.SUSPENDIDA) {
                s.setEstado(EstadoSuscripcion.EN_GRACIA);
            } else if (nuevoEstado == EstadoEmpresa.CANCELADA) {
                s.setEstado(EstadoSuscripcion.CANCELADA);
            } else if (nuevoEstado == EstadoEmpresa.ACTIVA) {
                s.setEstado(EstadoSuscripcion.ACTIVA);
            }
            s.setFechaEstado(LocalDateTime.now());
            suscripcionRepository.save(s);
        });

        TenantContext.setEmpresaId(empresaId);
        auditoriaService.registrar("CAMBIO_ESTADO_EMPRESA", "EMPRESA", String.valueOf(empresaId),
                "Estado " + anterior + " -> " + nuevoEstado);
        return empresa;
    }

    /** Vista de una empresa con suscripcion y uso de limites. */
    @Transactional(readOnly = true)
    public Map<String, Object> detalleEmpresa(Long empresaId) {
        exigirSuperAdmin();
        if (empresaId == null || empresaId <= TenantResolver.ROOT) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Empresa no encontrada");
        }
        Empresa empresa = empresaRepository.findById(empresaId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Empresa no encontrada"));
        Map<String, Object> vista = new LinkedHashMap<>();
        vista.put("empresa", empresa);
        suscripcionRepository.findByEmpresaId(empresaId).ifPresent(s -> {
            vista.put("suscripcion", s);
            vista.put("plan", s.getPlan());
        });
        vista.put("usuarios", usuarioRepository.findByEmpresaId(empresaId).size());
        vista.put("activos", activoRepository.countByEmpresaId(empresaId));
        return vista;
    }

    private void exigirSuperAdmin() {
        if (!TenantContext.esSuperAdmin()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Esta operacion es exclusiva del Super Admin de plataforma");
        }
    }
}
