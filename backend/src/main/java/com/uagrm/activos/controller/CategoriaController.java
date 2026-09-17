package com.uagrm.activos.controller;

import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.repository.CategoriaRepository;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/categorias")
public class CategoriaController {

    private final CategoriaRepository categoriaRepository;

    public CategoriaController(CategoriaRepository categoriaRepository) {
        this.categoriaRepository = categoriaRepository;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_LEER')")
    public List<Categoria> listar() {
        return categoriaRepository.findAll();
    }
}
