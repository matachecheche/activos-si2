package com.uagrm.activos.controller;

import com.uagrm.activos.model.Ubicacion;
import com.uagrm.activos.repository.UbicacionRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ubicaciones")
public class UbicacionController {

    private final UbicacionRepository ubicacionRepository;

    public UbicacionController(UbicacionRepository ubicacionRepository) {
        this.ubicacionRepository = ubicacionRepository;
    }

    @GetMapping
    public List<Ubicacion> listar() {
        return ubicacionRepository.findAll();
    }
}
