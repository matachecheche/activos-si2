package com.uagrm.activos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record PresupuestoRequest(
        @NotNull(message = "El área es obligatoria") Long areaId,
        @NotNull(message = "La gestión es obligatoria") @Min(value = 2000, message = "La gestión no es válida") @Max(value = 2100, message = "La gestión no es válida") Integer gestion,
        @NotNull(message = "El monto aprobado es obligatorio") @DecimalMin(value = "0.01", message = "El monto aprobado debe ser mayor a cero") BigDecimal montoAprobado
) {}
