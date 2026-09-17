package com.uagrm.activos.controller;

import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

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
}
