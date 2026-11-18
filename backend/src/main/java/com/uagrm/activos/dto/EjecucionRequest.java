package com.uagrm.activos.dto;

import com.uagrm.activos.model.TipoEjecucion;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record EjecucionRequest(
        @NotNull(message = "La partida es obligatoria") Long partidaId,
        @NotNull(message = "El tipo (compromiso o ejecución) es obligatorio") TipoEjecucion tipo,
        @NotNull(message = "La fecha es obligatoria") LocalDate fecha,
        @NotBlank(message = "El concepto es obligatorio") @Size(max = 200, message = "El concepto admite hasta 200 caracteres") String concepto,
        @NotNull(message = "El monto es obligatorio") @DecimalMin(value = "0.01", message = "El monto debe ser mayor a cero") BigDecimal monto,
        Long activoId,
        Long compromisoId
) {}
