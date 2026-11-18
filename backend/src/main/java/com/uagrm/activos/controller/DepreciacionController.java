package com.uagrm.activos.controller;

import com.uagrm.activos.dto.CalculoDepreciacionResponse;
import com.uagrm.activos.dto.DepreciacionActivoResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.DepreciacionService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.YearMonth;
import java.util.List;

/** HU-07: consulta y calculo de la depreciacion y del valor en libros. */
@RestController
@RequestMapping("/api/depreciacion")
public class DepreciacionController {

    private final DepreciacionService depreciacionService;

    public DepreciacionController(DepreciacionService depreciacionService) {
        this.depreciacionService = depreciacionService;
    }

    @GetMapping("/resumen")
    @PreAuthorize(Autorizacion.DEPRECIACION_LEER)
    public List<DepreciacionActivoResponse.Resumen> resumen() {
        return depreciacionService.resumenGeneral();
    }

    @GetMapping("/activo/{activoId}")
    @PreAuthorize(Autorizacion.DEPRECIACION_LEER)
    public DepreciacionActivoResponse tabla(@PathVariable Long activoId) {
        return depreciacionService.tabla(activoId);
    }

    /** Calcula los periodos pendientes de todos los activos hasta el periodo indicado (yyyy-MM, por defecto el actual). */
    @PostMapping("/calcular")
    @PreAuthorize(Autorizacion.DEPRECIACION_CREAR)
    public CalculoDepreciacionResponse calcular(@RequestParam(required = false) String periodo) {
        return depreciacionService.calcularTodos(parsear(periodo));
    }

    @PostMapping("/activo/{activoId}/calcular")
    @PreAuthorize(Autorizacion.DEPRECIACION_CREAR)
    public CalculoDepreciacionResponse calcularActivo(@PathVariable Long activoId, @RequestParam(required = false) String periodo) {
        return depreciacionService.calcularDeActivo(activoId, parsear(periodo));
    }

    private YearMonth parsear(String periodo) {
        if (periodo == null || periodo.isBlank()) {
            return YearMonth.now();
        }
        try {
            return YearMonth.parse(periodo.trim());
        } catch (Exception e) {
            throw new IllegalArgumentException("El periodo debe tener el formato yyyy-MM (por ejemplo 2026-10)");
        }
    }
}
