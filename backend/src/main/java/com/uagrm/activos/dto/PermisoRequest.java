package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotBlank;

public record PermisoRequest(
        @NotBlank(message = "El módulo es obligatorio") String modulo,
        @NotBlank(message = "La acción es obligatoria") String accion,
        @NotBlank(message = "La descripción es obligatoria") String descripcion
) {}
