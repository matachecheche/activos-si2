package com.uagrm.activos.controller;

import com.uagrm.activos.dto.AreaRequest;
import com.uagrm.activos.dto.AreaResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.AreaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/areas")
public class AreaController {

    private final AreaService areaService;

    public AreaController(AreaService areaService) {
        this.areaService = areaService;
    }

    @GetMapping
    @PreAuthorize(Autorizacion.AREAS_LEER)
    public List<AreaResponse> listar() {
        return areaService.listarAreas();
    }

    @PostMapping
    @PreAuthorize(Autorizacion.PRESUPUESTO_CREAR)
    @ResponseStatus(HttpStatus.CREATED)
    public AreaResponse crear(@Valid @RequestBody AreaRequest request) {
        return areaService.crearArea(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(Autorizacion.PRESUPUESTO_EDITAR)
    public AreaResponse actualizar(@PathVariable Long id, @Valid @RequestBody AreaRequest request) {
        return areaService.actualizarArea(id, request);
    }
}
