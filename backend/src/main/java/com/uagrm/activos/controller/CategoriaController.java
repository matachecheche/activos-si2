package com.uagrm.activos.controller;

import com.uagrm.activos.dto.CategoriaRequest;
import com.uagrm.activos.dto.CategoriaResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.CategoriaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/categorias")
public class CategoriaController {

    private final CategoriaService categoriaService;

    public CategoriaController(CategoriaService categoriaService) {
        this.categoriaService = categoriaService;
    }

    @GetMapping
    @PreAuthorize(Autorizacion.CATEGORIAS_LEER)
    public List<CategoriaResponse> listar() {
        return categoriaService.listar();
    }

    @PostMapping
    @PreAuthorize(Autorizacion.ACTIVOS_CREAR)
    @ResponseStatus(HttpStatus.CREATED)
    public CategoriaResponse crear(@Valid @RequestBody CategoriaRequest request) {
        return categoriaService.crear(request);
    }

    // HU-07: parametros de depreciacion (vida util, valor residual y metodo) por categoria
    @PutMapping("/{id}")
    @PreAuthorize(Autorizacion.CATEGORIAS_EDITAR)
    public CategoriaResponse actualizar(@PathVariable Long id, @Valid @RequestBody CategoriaRequest request) {
        return categoriaService.actualizar(id, request);
    }
}
