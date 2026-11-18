package com.uagrm.activos.controller;

import com.uagrm.activos.dto.AsignacionRequest;
import com.uagrm.activos.dto.AsignacionResponse;
import com.uagrm.activos.dto.UsuarioResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.AsignacionService;
import com.uagrm.activos.service.UsuarioService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/asignaciones")
public class AsignacionController {

    private final AsignacionService asignacionService;
    private final UsuarioService usuarioService;

    public AsignacionController(AsignacionService asignacionService, UsuarioService usuarioService) {
        this.asignacionService = asignacionService;
        this.usuarioService = usuarioService;
    }

    // HU-03: asignar activo a responsable y ubicacion
    @PostMapping
    @PreAuthorize(Autorizacion.ACTIVOS_EDITAR)
    public AsignacionResponse asignar(@Valid @RequestBody AsignacionRequest request) {
        return asignacionService.asignar(request);
    }

    @GetMapping("/activo/{activoId}")
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public List<AsignacionResponse> historial(@PathVariable Long activoId) {
        return asignacionService.historial(activoId);
    }

    // candidatos a responsable (quien asigna no necesita permiso para administrar usuarios)
    @GetMapping("/responsables")
    @PreAuthorize(Autorizacion.ACTIVOS_EDITAR)
    public List<UsuarioResponse> responsables() {
        return usuarioService.listarActivos();
    }
}
