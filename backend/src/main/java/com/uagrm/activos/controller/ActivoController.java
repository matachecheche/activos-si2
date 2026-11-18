package com.uagrm.activos.controller;

import com.uagrm.activos.dto.ActivoRequest;
import com.uagrm.activos.dto.ActivoResponse;
import com.uagrm.activos.dto.CambioEstadoRequest;
import com.uagrm.activos.dto.HistorialEstadoResponse;
import com.uagrm.activos.dto.MantenimientoActivoResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.ActivoService;
import com.uagrm.activos.service.EtiquetaService;
import com.uagrm.activos.service.MantenimientoService;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/activos")
public class ActivoController {

    private final ActivoService activoService;
    private final EtiquetaService etiquetaService;
    private final MantenimientoService mantenimientoService;

    public ActivoController(ActivoService activoService, EtiquetaService etiquetaService, MantenimientoService mantenimientoService) {
        this.activoService = activoService;
        this.etiquetaService = etiquetaService;
        this.mantenimientoService = mantenimientoService;
    }

    // HU-02: registrar / listar / editar activos fijos por categoria
    @GetMapping
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public List<ActivoResponse> listar() {
        return activoService.listar();
    }

    @GetMapping("/{id}")
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public ActivoResponse obtener(@PathVariable Long id) {
        try {
            return activoService.detalle(id);
        } catch (IllegalArgumentException ex) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.NOT_FOUND, ex.getMessage());
        }
    }

    @PostMapping
    @PreAuthorize(Autorizacion.ACTIVOS_CREAR)
    public ActivoResponse registrar(@Valid @RequestBody ActivoRequest request) {
        return activoService.registrar(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(Autorizacion.ACTIVOS_EDITAR)
    public ActivoResponse actualizar(@PathVariable Long id, @Valid @RequestBody ActivoRequest request) {
        return activoService.actualizar(id, request);
    }

    // HU-05: buscar un activo por su codigo unico (el mismo texto que codifica el QR)
    @GetMapping("/codigo/{codigo}")
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public ActivoResponse porCodigo(@PathVariable String codigo) {
        return activoService.porCodigo(codigo);
    }

    // HU-05: QR bajo demanda (PNG) y etiqueta imprimible (PDF)
    @GetMapping("/{id}/qr")
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public ResponseEntity<byte[]> qr(@PathVariable Long id, @RequestParam(required = false) Integer tamano) {
        byte[] png = etiquetaService.qrPng(id, tamano);
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_PNG)
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(png);
    }

    @GetMapping("/{id}/etiqueta.pdf")
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public ResponseEntity<byte[]> etiquetaPdf(@PathVariable Long id) {
        byte[] pdf = etiquetaService.etiquetaPdf(id);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"etiqueta-" + etiquetaService.codigo(id) + ".pdf\"")
                .body(pdf);
    }

    // HU-06: control del estado del activo
    @PostMapping("/{id}/estado")
    @PreAuthorize(Autorizacion.ACTIVOS_EDITAR)
    public ActivoResponse cambiarEstado(@PathVariable Long id, @Valid @RequestBody CambioEstadoRequest request) {
        return activoService.cambiarEstado(id, request);
    }

    @GetMapping("/{id}/historial-estados")
    @PreAuthorize(Autorizacion.ACTIVOS_LEER)
    public List<HistorialEstadoResponse> historialEstados(@PathVariable Long id) {
        return activoService.historialEstados(id);
    }

    // HU-08: historial de mantenimientos del activo y costo total acumulado
    @GetMapping("/{id}/mantenimientos")
    @PreAuthorize(Autorizacion.MANTENIMIENTO_LEER)
    public MantenimientoActivoResponse mantenimientos(@PathVariable Long id) {
        return mantenimientoService.porActivo(id);
    }
}
