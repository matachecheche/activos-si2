package com.uagrm.activos.controller;

import com.uagrm.activos.dto.AlertasMantenimientoResponse;
import com.uagrm.activos.dto.MantenimientoCancelarRequest;
import com.uagrm.activos.dto.MantenimientoFinalizarRequest;
import com.uagrm.activos.dto.MantenimientoRequest;
import com.uagrm.activos.dto.MantenimientoResponse;
import com.uagrm.activos.model.EstadoMantenimiento;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.MantenimientoService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** HU-08: programar, iniciar, finalizar y cancelar mantenimientos. */
@RestController
@RequestMapping("/api/mantenimientos")
public class MantenimientoController {

    private final MantenimientoService mantenimientoService;

    public MantenimientoController(MantenimientoService mantenimientoService) {
        this.mantenimientoService = mantenimientoService;
    }

    @GetMapping
    @PreAuthorize(Autorizacion.MANTENIMIENTO_LEER)
    public List<MantenimientoResponse> listar(@RequestParam(required = false) Long activoId,
                                              @RequestParam(required = false) EstadoMantenimiento estado) {
        return mantenimientoService.listar(activoId, estado);
    }

    @GetMapping("/alertas")
    @PreAuthorize(Autorizacion.MANTENIMIENTO_LEER)
    public AlertasMantenimientoResponse alertas() {
        return mantenimientoService.alertas();
    }

    @PostMapping
    @PreAuthorize(Autorizacion.MANTENIMIENTO_CREAR)
    @ResponseStatus(HttpStatus.CREATED)
    public MantenimientoResponse programar(@Valid @RequestBody MantenimientoRequest request) {
        return mantenimientoService.programar(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(Autorizacion.MANTENIMIENTO_EDITAR)
    public MantenimientoResponse actualizar(@PathVariable Long id, @Valid @RequestBody MantenimientoRequest request) {
        return mantenimientoService.actualizar(id, request);
    }

    @PostMapping("/{id}/iniciar")
    @PreAuthorize(Autorizacion.MANTENIMIENTO_EDITAR)
    public MantenimientoResponse iniciar(@PathVariable Long id) {
        return mantenimientoService.iniciar(id);
    }

    @PostMapping("/{id}/finalizar")
    @PreAuthorize(Autorizacion.MANTENIMIENTO_EDITAR)
    public MantenimientoResponse finalizar(@PathVariable Long id, @Valid @RequestBody MantenimientoFinalizarRequest request) {
        return mantenimientoService.finalizar(id, request);
    }

    @PostMapping("/{id}/cancelar")
    @PreAuthorize(Autorizacion.MANTENIMIENTO_EDITAR)
    public MantenimientoResponse cancelar(@PathVariable Long id, @Valid @RequestBody(required = false) MantenimientoCancelarRequest request) {
        return mantenimientoService.cancelar(id, request);
    }
}
