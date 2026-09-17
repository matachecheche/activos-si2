package com.uagrm.activos.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record UsuarioRequest(
        @NotBlank String nombre,
        @NotBlank @Email String correo,
        String password,
        @NotBlank String rol
) {}