package com.uagrm.activos.controller;

import com.uagrm.activos.dto.PermisoRequest;
import com.uagrm.activos.dto.PermisoResponse;
import com.uagrm.activos.dto.RolOpcionResponse;
import com.uagrm.activos.dto.RolRequest;
import com.uagrm.activos.dto.RolResponse;
import com.uagrm.activos.security.Autorizacion;
import com.uagrm.activos.service.RolService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** HU-04: administrar roles y permisos por modulo y accion (solo el administrador). */
@RestController
@RequestMapping("/api/roles")
public class RolController {
    private final RolService rolService;

    public RolController(RolService rolService) {
        this.rolService = rolService;
    }

    @GetMapping
    @PreAuthorize(Autorizacion.ADMIN)
    public List<RolResponse> listarRoles() { return rolService.listar(); }

    // roles activos asignables: lo usa la pantalla de usuarios
    @GetMapping("/disponibles")
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_USUARIOS_LEER') or hasAuthority('PERM_USUARIOS_CREAR') or hasAuthority('PERM_USUARIOS_EDITAR')")
    public List<RolOpcionResponse> disponibles() { return rolService.disponibles(); }

    @GetMapping("/permisos")
    @PreAuthorize(Autorizacion.ADMIN)
    public List<PermisoResponse> listarPermisos() { return rolService.listarPermisos(); }

    @PostMapping("/permisos")
    @PreAuthorize(Autorizacion.ADMIN)
    @ResponseStatus(HttpStatus.CREATED)
    public PermisoResponse crearPermiso(@Valid @RequestBody PermisoRequest request) { return rolService.crearPermiso(request); }

    @PutMapping("/permisos/{id}")
    @PreAuthorize(Autorizacion.ADMIN)
    public PermisoResponse actualizarPermiso(@PathVariable Long id, @Valid @RequestBody PermisoRequest request) {
        return rolService.actualizarPermiso(id, request);
    }

    @DeleteMapping("/permisos/{id}")
    @PreAuthorize(Autorizacion.ADMIN)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminarPermiso(@PathVariable Long id) { rolService.eliminarPermiso(id); }

    @PostMapping
    @PreAuthorize(Autorizacion.ADMIN)
    @ResponseStatus(HttpStatus.CREATED)
    public RolResponse crear(@Valid @RequestBody RolRequest request) { return rolService.crear(request); }

    @PutMapping("/{id}")
    @PreAuthorize(Autorizacion.ADMIN)
    public RolResponse actualizar(@PathVariable Long id, @Valid @RequestBody RolRequest request) {
        return rolService.actualizar(id, request);
    }

    // desactiva el rol (no se puede si tiene usuarios activos asignados)
    @DeleteMapping("/{id}")
    @PreAuthorize(Autorizacion.ADMIN)
    public RolResponse desactivar(@PathVariable Long id) { return rolService.desactivar(id); }
}
