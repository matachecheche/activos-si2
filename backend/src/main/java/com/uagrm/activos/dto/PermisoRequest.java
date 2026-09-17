package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotBlank;

public record PermisoRequest(
        @NotBlank String modulo,
        @NotBlank String accion,
        @NotBlank String descripcion
) {}