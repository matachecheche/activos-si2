package com.uagrm.activos.dto;

import com.uagrm.activos.model.TipoMantenimiento;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/** HU-08: programa un preventivo (fecha programada) o registra un correctivo (falla). */
public record MantenimientoRequest(
        @NotNull(message = "El activo es obligatorio") Long activoId,
        @NotNull(message = "El tipo de mantenimiento es obligatorio") TipoMantenimiento tipo,
        @Size(max = 500, message = "La descripción admite hasta 500 caracteres") String descripcion,
        LocalDate fechaProgramada,
        @Min(value = 1, message = "La periodicidad debe ser de al menos 1 día") Integer periodicidadDias
) {}
