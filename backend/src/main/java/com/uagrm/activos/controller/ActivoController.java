package com.uagrm.activos.controller;

import com.uagrm.activos.dto.ActivoRequest;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.service.ActivoService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

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
    public List<Activo> listar() {
        return activoService.listar();
    }

    @GetMapping("/{id}")
    public Activo obtener(@PathVariable Long id) {
        return activoService.obtener(id);
    }

    @PostMapping
    public Activo registrar(@Valid @RequestBody ActivoRequest request) {
        return activoService.registrar(request);
    }

    @PutMapping("/{id}")
    public Activo actualizar(@PathVariable Long id, @Valid @RequestBody ActivoRequest request) {
        return activoService.actualizar(id, request);
    }
}
