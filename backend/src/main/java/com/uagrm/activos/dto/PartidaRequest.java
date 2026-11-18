package com.uagrm.activos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record PartidaRequest(
        @NotBlank(message = "El código de la partida es obligatorio") @Size(max = 30, message = "El código admite hasta 30 caracteres") String codigo,
        @NotBlank(message = "El nombre de la partida es obligatorio") @Size(max = 150, message = "El nombre admite hasta 150 caracteres") String nombre,
        @NotNull(message = "El monto planificado es obligatorio") @DecimalMin(value = "0.01", message = "El monto planificado debe ser mayor a cero") BigDecimal montoPlanificado
) {}
