package com.uagrm.activos.controller;

import com.uagrm.activos.dto.*;
import com.uagrm.activos.model.Permiso;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.repository.RolRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/roles")
public class RolController {
    private final RolRepository rolRepository;
    private final PermisoRepository permisoRepository;

    public RolController(RolRepository rolRepository, PermisoRepository permisoRepository) {
        this.rolRepository = rolRepository;
        this.permisoRepository = permisoRepository;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    public List<RolResponse> listarRoles() { return rolRepository.findAll().stream().map(this::respuesta).toList(); }

    @GetMapping("/permisos")
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    public List<PermisoResponse> listarPermisos() { return permisoRepository.findAll().stream().map(this::permisoRespuesta).toList(); }

    @PostMapping("/permisos")
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    @ResponseStatus(HttpStatus.CREATED)
    public PermisoResponse crearPermiso(@Valid @RequestBody PermisoRequest request) {
        if (permisoRepository.findAll().stream().anyMatch(p -> p.getModulo().equalsIgnoreCase(request.modulo().trim()) && p.getAccion().equalsIgnoreCase(request.accion().trim()))) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe ese permiso");
        }
        Permiso permiso = Permiso.builder().modulo(request.modulo().trim().toUpperCase()).accion(request.accion().trim().toUpperCase()).descripcion(request.descripcion().trim()).build();
        return permisoRespuesta(permisoRepository.save(permiso));
    }

    @PutMapping("/permisos/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    public PermisoResponse actualizarPermiso(@PathVariable Long id, @Valid @RequestBody PermisoRequest request) {
        Permiso permiso = permisoRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Permiso no encontrado"));
        if (permisoRepository.findAll().stream().anyMatch(p -> !p.getId().equals(id) && p.getModulo().equalsIgnoreCase(request.modulo().trim()) && p.getAccion().equalsIgnoreCase(request.accion().trim()))) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe ese permiso");
        }
        permiso.setModulo(request.modulo().trim().toUpperCase());
        permiso.setAccion(request.accion().trim().toUpperCase());
        permiso.setDescripcion(request.descripcion().trim());
        return permisoRespuesta(permisoRepository.save(permiso));
    }

    @DeleteMapping("/permisos/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminarPermiso(@PathVariable Long id) {
        if (!permisoRepository.existsById(id)) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Permiso no encontrado");
        rolRepository.findAll().forEach(rol -> {
            rol.getPermisos().removeIf(permiso -> permiso.getId().equals(id));
            rolRepository.save(rol);
        });
        permisoRepository.deleteById(id);
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    @ResponseStatus(HttpStatus.CREATED)
    public RolResponse crear(@Valid @RequestBody RolRequest request) { return guardar(new Rol(), request); }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    public RolResponse actualizar(@PathVariable Long id, @Valid @RequestBody RolRequest request) {
        Rol rol = rolRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Rol no encontrado"));
        return guardar(rol, request);
    }

    private RolResponse guardar(Rol rol, RolRequest request) {
        rol.setNombre(request.nombre().trim().toUpperCase());
        Set<Permiso> permisos = request.permisos() == null ? Set.of() : request.permisos().stream().map(id -> permisoRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Permiso no encontrado: " + id))).collect(Collectors.toSet());
        rol.setPermisos(permisos);
        return respuesta(rolRepository.save(rol));
    }

    private RolResponse respuesta(Rol rol) {
        Set<Permiso> permisos = "ADMINISTRADOR".equalsIgnoreCase(rol.getNombre())
            ? new java.util.HashSet<>(permisoRepository.findAll()) : rol.getPermisos();
        return new RolResponse(rol.getId(), rol.getNombre(), permisos.stream().map(this::permisoRespuesta).collect(Collectors.toSet()));
    }

    private PermisoResponse permisoRespuesta(Permiso permiso) { return new PermisoResponse(permiso.getId(), permiso.getModulo(), permiso.getAccion(), permiso.getDescripcion()); }
}
