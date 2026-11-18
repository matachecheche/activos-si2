package com.uagrm.activos.controller;

import com.uagrm.activos.ia.ResultadoConsulta;
import com.uagrm.activos.model.ConsultaGuardada;
import com.uagrm.activos.reportes.ConsultaGuardadaService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/** HU-14: CRUD de consultas dinamicas guardadas. */
@RestController
@RequestMapping("/api/consultas-guardadas")
@PreAuthorize("hasAuthority('PERM_REPORTES_LEER')")
public class ConsultaGuardadaController {

    private final ConsultaGuardadaService service;

    public ConsultaGuardadaController(ConsultaGuardadaService service) {
        this.service = service;
    }

    @GetMapping
    public List<ConsultaGuardada> listar() {
        return service.listar();
    }

    @PostMapping
    public ConsultaGuardada guardar(@RequestBody Map<String, String> body) {
        return service.guardar(body.get("nombre"), body.get("entidad"), body.get("definicion"));
    }

    @GetMapping("/{id}/ejecutar")
    public ResultadoConsulta ejecutar(@PathVariable Long id) {
        return service.ejecutar(id);
    }

    @DeleteMapping("/{id}")
    public void eliminar(@PathVariable Long id) {
        service.eliminar(id);
    }
}
