package com.uagrm.activos.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * HU-09/HU-10: montoAprobado es el tope del presupuesto; montoPlanificado es la suma de sus
 * partidas; saldoDisponible = planificado - (comprometido + ejecutado).
 */
public record PresupuestoResponse(
        Long id,
        Long areaId,
        String areaNombre,
        Integer gestion,
        BigDecimal montoAprobado,
        String estado,
        LocalDateTime fechaAprobacion,
        String aprobador,
        BigDecimal montoPlanificado,
        BigDecimal sinDistribuir,
        BigDecimal comprometido,
        BigDecimal ejecutado,
        BigDecimal saldoDisponible,
        BigDecimal porcentajeEjecucion
) {}
