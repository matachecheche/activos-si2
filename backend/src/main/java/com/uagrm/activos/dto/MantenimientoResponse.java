package com.uagrm.activos.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record MantenimientoResponse(
        Long id,
        Long activoId,
        String activoCodigo,
        String activoNombre,
        String tipo,
        String estado,
        String descripcion,
        LocalDate fechaProgramada,
        Integer periodicidadDias,
        LocalDateTime fechaInicio,
        LocalDate fechaRealizada,
        BigDecimal costo,
        String tecnico,
        String observaciones,
        Long diasParaVencer
) {}
