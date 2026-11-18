package com.uagrm.activos.controller;

import com.uagrm.activos.model.ProgramacionRespaldo;
import com.uagrm.activos.model.Respaldo;
import com.uagrm.activos.respaldo.RespaldoService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** HU-16: respaldos manuales/programados, descarga y restauracion. */
@RestController
@RequestMapping("/api/respaldos")
@PreAuthorize("hasAuthority('PERM_RESPALDO_GESTIONAR')")
public class RespaldoController {

    private final RespaldoService service;

    public RespaldoController(RespaldoService service) {
        this.service = service;
    }

    @GetMapping
    public List<Respaldo> listar() {
        return service.listar();
    }

    @PostMapping
    public Respaldo crear() {
        return service.respaldoManual();
    }

    @GetMapping("/{id}/descargar")
    public ResponseEntity<byte[]> descargar(@PathVariable Long id) {
        byte[] contenido = service.contenidoDe(id);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=" + service.nombreArchivo(id))
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(contenido);
    }

    @PostMapping("/{id}/restaurar")
    public Respaldo restaurar(@PathVariable Long id) {
        return service.restaurar(id);
    }

    @GetMapping("/programacion")
    public ProgramacionRespaldo verProgramacion() {
        return service.verProgramacion();
    }

    @PutMapping("/programacion")
    public ProgramacionRespaldo guardarProgramacion(@RequestBody ProgramacionRespaldo entrada) {
        return service.guardarProgramacion(entrada);
    }
}
