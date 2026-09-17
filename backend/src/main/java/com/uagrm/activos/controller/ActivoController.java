package com.uagrm.activos.controller;

import com.uagrm.activos.dto.ActivoRequest;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.service.ActivoService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/activos")
public class ActivoController {

    private final ActivoService activoService;

    public ActivoController(ActivoService activoService) {
        this.activoService = activoService;
    }

    // HU-02: registrar / listar / editar activos fijos por categoria
    @GetMapping
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_LEER')")
    public List<Activo> listar() {
        return activoService.listar();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_LEER')")
    public Activo obtener(@PathVariable Long id) {
        return activoService.obtener(id);
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_CREAR')")
    public Activo registrar(@Valid @RequestBody ActivoRequest request) {
        return activoService.registrar(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_EDITAR')")
    public Activo actualizar(@PathVariable Long id, @Valid @RequestBody ActivoRequest request) {
        return activoService.actualizar(id, request);
    }
}
