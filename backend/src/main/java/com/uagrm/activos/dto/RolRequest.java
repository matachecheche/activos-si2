package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.Set;

public record RolRequest(
        @NotBlank(message = "El nombre del rol es obligatorio") @Size(max = 50, message = "El nombre admite hasta 50 caracteres") String nombre,
        @Size(max = 160, message = "La descripción admite hasta 160 caracteres") String descripcion,
        Set<Long> permisos,
        Boolean activo
) {}
