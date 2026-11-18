package com.uagrm.activos.controller;

import com.uagrm.activos.dto.UbicacionRequest;
import com.uagrm.activos.dto.UbicacionResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.AreaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/ubicaciones")
public class UbicacionController {

    private final AreaService areaService;

    public UbicacionController(AreaService areaService) {
        this.areaService = areaService;
    }

    @GetMapping
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public List<UbicacionResponse> listar() {
        return areaService.listarUbicaciones();
    }

    @PostMapping
    @PreAuthorize(Autorizacion.ACTIVOS_CREAR)
    @ResponseStatus(HttpStatus.CREATED)
    public UbicacionResponse crear(@Valid @RequestBody UbicacionRequest request) {
        return areaService.crearUbicacion(request);
    }
}
