package com.uagrm.activos.controller;

import com.uagrm.activos.dto.EmpresaSesionDto;
import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * HU-01: iniciar sesion con correo institucional y contrasena.
 * Sprint 3 / multiempresa: listar las empresas del usuario y cambiar de
 * empresa sin volver a autenticarse.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    // HU-01: iniciar sesion con correo institucional y contrasena
    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    /** Empresas a las que el usuario tiene acceso (con su rol en cada una). */
    @GetMapping("/mis-empresas")
    public List<EmpresaSesionDto> misEmpresas() {
        return authService.misEmpresas(correoActual());
    }

    /** Cambia de empresa y devuelve un token nuevo con el rol de esa empresa. */
    @PostMapping("/cambiar-empresa")
    public LoginResponse cambiarEmpresa(@RequestBody Map<String, Object> cuerpo) {
        Object crudo = cuerpo.get("empresaId");
        if (crudo == null) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "Indique la empresa a la que quiere cambiar");
        }
        Long empresaId = Long.valueOf(crudo.toString());
        return authService.cambiarEmpresa(correoActual(), empresaId);
    }

    private String correoActual() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.UNAUTHORIZED, "Sesión no válida");
        }
        return auth.getName();
    }
}
