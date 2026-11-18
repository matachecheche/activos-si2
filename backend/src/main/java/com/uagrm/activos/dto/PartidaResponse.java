package com.uagrm.activos.dto;

import java.math.BigDecimal;

public record PartidaResponse(
        Long id,
        Long presupuestoId,
        String codigo,
        String nombre,
        BigDecimal montoPlanificado,
        BigDecimal comprometido,
        BigDecimal ejecutado,
        BigDecimal saldoDisponible,
        BigDecimal porcentajeEjecucion
) {}
