package com.uagrm.activos.controller;

import com.uagrm.activos.dto.UsuarioRequest;
import com.uagrm.activos.dto.UsuarioResponse;
import com.uagrm.activos.service.UsuarioService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/api/usuarios")
public class UsuarioController {
    private final UsuarioService usuarioService;

    public UsuarioController(UsuarioService usuarioService) {
        this.usuarioService = usuarioService;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_USUARIOS_LEER')")
    public List<UsuarioResponse> listar() { return usuarioService.listar(); }

    @PostMapping
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_USUARIOS_CREAR')")
    @ResponseStatus(HttpStatus.CREATED)
    public UsuarioResponse crear(@Valid @RequestBody UsuarioRequest request) { return usuarioService.crear(request); }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_USUARIOS_EDITAR')")
    public UsuarioResponse actualizar(@PathVariable Long id, @Valid @RequestBody UsuarioRequest request) { return usuarioService.actualizar(id, request); }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR') or hasAuthority('PERM_USUARIOS_ELIMINAR')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminar(@PathVariable Long id) { usuarioService.eliminar(id); }
}