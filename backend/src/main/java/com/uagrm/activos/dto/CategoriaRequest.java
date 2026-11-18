package com.uagrm.activos.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/** HU-07: parametrizacion de la depreciacion por categoria. */
public record CategoriaRequest(
        @NotBlank(message = "El nombre de la categoría es obligatorio") @Size(max = 100, message = "El nombre admite hasta 100 caracteres") String nombre,
        @Min(value = 1, message = "La vida útil debe ser de al menos 1 año") @Max(value = 100, message = "La vida útil máxima es de 100 años") Integer vidaUtil,
        @DecimalMin(value = "0.00", message = "El valor residual no puede ser negativo")
        @DecimalMax(value = "100.00", message = "El valor residual no puede superar el 100 %") BigDecimal valorResidualPct,
        Boolean depreciable,
        String metodoDepreciacion
) {}
