package com.uagrm.activos.controller;

import com.uagrm.activos.dto.EjecucionRequest;
import com.uagrm.activos.dto.EjecucionResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.EjecucionService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/** HU-10: registro de compromisos y ejecuciones sobre las partidas de un presupuesto aprobado. */
@RestController
@RequestMapping("/api/ejecuciones")
public class EjecucionController {

    private final EjecucionService ejecucionService;

    public EjecucionController(EjecucionService ejecucionService) {
        this.ejecucionService = ejecucionService;
    }

    @PostMapping
    @PreAuthorize(Autorizacion.PRESUPUESTO_CREAR)
    @ResponseStatus(HttpStatus.CREATED)
    public EjecucionResponse registrar(@Valid @RequestBody EjecucionRequest request) {
        return ejecucionService.registrar(request);
    }
}
