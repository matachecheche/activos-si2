package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UbicacionRequest(
        @NotBlank(message = "El nombre de la ubicación es obligatorio") @Size(max = 150, message = "El nombre admite hasta 150 caracteres") String nombre,
        Long areaId
) {}
