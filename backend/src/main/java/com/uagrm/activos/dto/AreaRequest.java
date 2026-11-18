package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AreaRequest(
        @NotBlank(message = "El nombre del área es obligatorio") @Size(max = 120, message = "El nombre admite hasta 120 caracteres") String nombre,
        @Size(max = 200, message = "La descripción admite hasta 200 caracteres") String descripcion,
        Boolean activo
) {}
