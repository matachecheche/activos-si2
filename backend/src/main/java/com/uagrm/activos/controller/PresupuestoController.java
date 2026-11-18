package com.uagrm.activos.controller;

import com.uagrm.activos.dto.EjecucionResponse;
import com.uagrm.activos.dto.PartidaRequest;
import com.uagrm.activos.dto.PartidaResponse;
import com.uagrm.activos.dto.PresupuestoRequest;
import com.uagrm.activos.dto.PresupuestoResponse;
import com.uagrm.activos.dto.SeguimientoResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.EjecucionService;
import com.uagrm.activos.service.PresupuestoService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** HU-09: presupuesto anual por gestion y area, con partidas, aprobacion y cierre. */
@RestController
@RequestMapping("/api/presupuestos")
public class PresupuestoController {

    private final PresupuestoService presupuestoService;
    private final EjecucionService ejecucionService;

    public PresupuestoController(PresupuestoService presupuestoService, EjecucionService ejecucionService) {
        this.presupuestoService = presupuestoService;
        this.ejecucionService = ejecucionService;
    }

    @GetMapping
    @PreAuthorize(Autorizacion.PRESUPUESTO_LEER)
    public List<PresupuestoResponse> listar(@RequestParam(required = false) Integer gestion,
                                            @RequestParam(required = false) Long areaId) {
        return presupuestoService.listar(gestion, areaId);
    }

    @GetMapping("/{id}")
    @PreAuthorize(Autorizacion.PRESUPUESTO_LEER)
    public PresupuestoResponse obtener(@PathVariable Long id) {
        return presupuestoService.obtener(id);
    }

    @PostMapping
    @PreAuthorize(Autorizacion.PRESUPUESTO_CREAR)
    @ResponseStatus(HttpStatus.CREATED)
    public PresupuestoResponse crear(@Valid @RequestBody PresupuestoRequest request) {
        return presupuestoService.crear(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(Autorizacion.PRESUPUESTO_EDITAR)
    public PresupuestoResponse actualizar(@PathVariable Long id, @Valid @RequestBody PresupuestoRequest request) {
        return presupuestoService.actualizar(id, request);
    }

    @PostMapping("/{id}/aprobar")
    @PreAuthorize(Autorizacion.PRESUPUESTO_EDITAR)
    public PresupuestoResponse aprobar(@PathVariable Long id) {
        return presupuestoService.aprobar(id);
    }

    @PostMapping("/{id}/cerrar")
    @PreAuthorize(Autorizacion.PRESUPUESTO_EDITAR)
    public PresupuestoResponse cerrar(@PathVariable Long id) {
        return presupuestoService.cerrar(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize(Autorizacion.PRESUPUESTO_ELIMINAR)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminar(@PathVariable Long id) {
        presupuestoService.eliminar(id);
    }

    // ---- partidas ----

    @GetMapping("/{id}/partidas")
    @PreAuthorize(Autorizacion.PRESUPUESTO_LEER)
    public List<PartidaResponse> partidas(@PathVariable Long id) {
        return presupuestoService.partidas(id);
    }

    @PostMapping("/{id}/partidas")
    @PreAuthorize(Autorizacion.PRESUPUESTO_CREAR)
    @ResponseStatus(HttpStatus.CREATED)
    public PartidaResponse crearPartida(@PathVariable Long id, @Valid @RequestBody PartidaRequest request) {
        return presupuestoService.crearPartida(id, request);
    }

    @PutMapping("/{id}/partidas/{partidaId}")
    @PreAuthorize(Autorizacion.PRESUPUESTO_EDITAR)
    public PartidaResponse actualizarPartida(@PathVariable Long id, @PathVariable Long partidaId,
                                             @Valid @RequestBody PartidaRequest request) {
        return presupuestoService.actualizarPartida(id, partidaId, request);
    }

    @DeleteMapping("/{id}/partidas/{partidaId}")
    @PreAuthorize(Autorizacion.PRESUPUESTO_EDITAR)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminarPartida(@PathVariable Long id, @PathVariable Long partidaId) {
        presupuestoService.eliminarPartida(id, partidaId);
    }

    // ---- HU-10: seguimiento (planificado vs. ejecutado) y movimientos ----

    @GetMapping("/{id}/seguimiento")
    @PreAuthorize(Autorizacion.PRESUPUESTO_LEER)
    public SeguimientoResponse seguimiento(@PathVariable Long id) {
        return presupuestoService.seguimiento(id);
    }

    @GetMapping("/{id}/ejecuciones")
    @PreAuthorize(Autorizacion.PRESUPUESTO_LEER)
    public List<EjecucionResponse> ejecuciones(@PathVariable Long id) {
        return ejecucionService.listar(id);
    }
}
