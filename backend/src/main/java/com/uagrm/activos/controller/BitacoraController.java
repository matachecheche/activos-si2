package com.uagrm.activos.controller;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.model.BitacoraAuditoria;
import com.uagrm.activos.repository.BitacoraAuditoriaRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

/** HU-13: consulta de la bitacora inmutable con filtros y verificacion de cadena de hashes. */
@RestController
@RequestMapping("/api/auditoria")
public class BitacoraController {

    private final BitacoraAuditoriaRepository repo;
    private final AuditoriaService auditoriaService;

    public BitacoraController(BitacoraAuditoriaRepository repo, AuditoriaService auditoriaService) {
        this.repo = repo;
        this.auditoriaService = auditoriaService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_AUDITORIA_LEER')")
    public Page<BitacoraAuditoria> listar(
            @RequestParam(required = false) String usuario,
            @RequestParam(required = false) String accion,
            @RequestParam(required = false) String entidad,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime hasta,
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "20") int tamano) {
        LocalDateTime d = desde == null ? LocalDateTime.of(2000, 1, 1, 0, 0) : desde;
        LocalDateTime h = hasta == null ? LocalDateTime.now().plusDays(1) : hasta;
        // El Super Admin puede auditar la plataforma entera pasando empresaId; las empresas solo ven lo suyo.
        Long empresaId = TenantContext.esSuperAdmin() ? null : TenantContext.getEmpresaId();
        return repo.buscar(empresaId,
                usuario == null ? "" : usuario,
                accion == null ? "" : accion,
                entidad == null ? "" : entidad, d, h,
                PageRequest.of(pagina, Math.min(tamano, 200), Sort.by(Sort.Direction.DESC, "id")));
    }

    @PostMapping("/verificar")
    @PreAuthorize("hasAuthority('PERM_AUDITORIA_LEER')")
    public Map<String, Object> verificar() {
        int alterados = auditoriaService.verificarIntegridad();
        return Map.of("integra", alterados == 0, "registrosAlterados", alterados);
    }
}
