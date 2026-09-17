package com.uagrm.activos.controller;

import com.uagrm.activos.dto.AsignacionRequest;
import com.uagrm.activos.model.Asignacion;
import com.uagrm.activos.service.AsignacionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/asignaciones")
public class AsignacionController {

    private final AsignacionService asignacionService;

    public AsignacionController(AsignacionService asignacionService) {
        this.asignacionService = asignacionService;
    }

    // HU-03: asignar activo a responsable y ubicacion
    @PostMapping
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_EDITAR')")
    public Asignacion asignar(@Valid @RequestBody AsignacionRequest request) {
        return asignacionService.asignar(request);
    }

    @GetMapping("/activo/{activoId}")
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_LEER')")
    public List<Asignacion> historial(@PathVariable Long activoId) {
        return asignacionService.historial(activoId);
    }
}
