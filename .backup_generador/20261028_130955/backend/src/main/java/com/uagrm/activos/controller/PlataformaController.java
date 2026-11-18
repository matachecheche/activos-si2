package com.uagrm.activos.controller;

import com.uagrm.activos.model.Empresa;
import com.uagrm.activos.model.EstadoEmpresa;
import com.uagrm.activos.saas.EmpresaAdminService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/** HU-12: administracion de la plataforma, reservada al Super Admin. */
@RestController
@RequestMapping("/api/plataforma")
@PreAuthorize("hasRole('SUPER_ADMIN')")
public class PlataformaController {

    private final EmpresaAdminService empresaAdminService;

    public PlataformaController(EmpresaAdminService empresaAdminService) {
        this.empresaAdminService = empresaAdminService;
    }

    @GetMapping("/empresas")
    public List<Empresa> empresas() {
        return empresaAdminService.listarEmpresas();
    }

    @GetMapping("/metricas")
    public Map<String, Object> metricas() {
        return empresaAdminService.metricasPlataforma();
    }

    @GetMapping("/empresas/{id}")
    public Map<String, Object> detalle(@PathVariable Long id) {
        return empresaAdminService.detalleEmpresa(id);
    }

    @PostMapping("/empresas/{id}/estado")
    public Empresa cambiarEstado(@PathVariable Long id, @RequestParam EstadoEmpresa estado) {
        return empresaAdminService.cambiarEstado(id, estado);
    }
}
