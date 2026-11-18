package com.uagrm.activos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record MantenimientoFinalizarRequest(
        LocalDate fechaRealizada,
        @NotNull(message = "El costo es obligatorio") @DecimalMin(value = "0.00", message = "El costo no puede ser negativo") BigDecimal costo,
        @NotBlank(message = "El técnico responsable es obligatorio") @Size(max = 150, message = "El técnico admite hasta 150 caracteres") String tecnico,
        @Size(max = 500, message = "Las observaciones admiten hasta 500 caracteres") String observaciones
) {}
