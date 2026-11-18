package com.uagrm.activos.controller;

import com.uagrm.activos.dto.SuscripcionRequest;
import com.uagrm.activos.saas.SuscripcionService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/** HU-11: la empresa administra su propia suscripcion y sus pagos. */
@RestController
@RequestMapping("/api/suscripcion")
public class SuscripcionController {

    private final SuscripcionService suscripcionService;

    public SuscripcionController(SuscripcionService suscripcionService) {
        this.suscripcionService = suscripcionService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_SUSCRIPCION_LEER')")
    public Map<String, Object> miSuscripcion() {
        return suscripcionService.miSuscripcion();
    }

    @PostMapping("/contratar")
    @PreAuthorize("hasAuthority('PERM_SUSCRIPCION_EDITAR')")
    public Map<String, Object> contratar(@Valid @RequestBody SuscripcionRequest request) {
        return suscripcionService.contratar(request);
    }
}
