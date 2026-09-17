package com.uagrm.activos.controller;

import com.uagrm.activos.model.Ubicacion;
import com.uagrm.activos.repository.UbicacionRepository;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/ubicaciones")
public class UbicacionController {

    private final UbicacionRepository ubicacionRepository;

    public UbicacionController(UbicacionRepository ubicacionRepository) {
        this.ubicacionRepository = ubicacionRepository;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_ACTIVOS_LEER')")
    public List<Ubicacion> listar() {
        return ubicacionRepository.findAll();
    }
}
