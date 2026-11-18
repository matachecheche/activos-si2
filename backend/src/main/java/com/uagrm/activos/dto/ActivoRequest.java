package com.uagrm.activos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

/** HU-02: campos obligatorios para registrar o editar un activo. */
public record ActivoRequest(
        @NotBlank(message = "El nombre es obligatorio") @Size(max = 150, message = "El nombre admite hasta 150 caracteres") String nombre,
        @NotNull(message = "La categoría es obligatoria") Long categoriaId,
        @NotNull(message = "El valor de adquisición es obligatorio")
        @DecimalMin(value = "0.01", message = "El valor de adquisición no puede ser negativo ni cero") BigDecimal valor,
        @NotNull(message = "La fecha de adquisición es obligatoria") LocalDate fechaAdquisicion,
        @Size(max = 150, message = "El proveedor admite hasta 150 caracteres") String proveedor,
        @Size(max = 255, message = "Las observaciones admiten hasta 255 caracteres") String observaciones,
        @DecimalMin(value = "0.00", message = "El valor residual no puede ser negativo") BigDecimal valorResidual,
        LocalDate fechaInicioDepreciacion
) {}
