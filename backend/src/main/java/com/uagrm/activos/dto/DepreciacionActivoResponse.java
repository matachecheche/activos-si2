package com.uagrm.activos.dto;

import java.math.BigDecimal;
import java.util.List;

/** HU-07: tabla de depreciacion por activo con su resumen. */
public record DepreciacionActivoResponse(Resumen resumen, List<Fila> filas) {

    public record Resumen(
            Long activoId,
            String codigo,
            String nombre,
            String categoria,
            String estado,
            boolean depreciable,
            String observacion,
            BigDecimal valorAdquisicion,
            BigDecimal valorResidual,
            Integer vidaUtilAnios,
            Integer vidaUtilMeses,
            BigDecimal depreciacionMensual,
            BigDecimal depreciacionAcumulada,
            BigDecimal valorEnLibros,
            int periodosCalculados,
            String ultimoPeriodo
    ) {}

    public record Fila(
            String periodo,
            BigDecimal depreciacionPeriodo,
            BigDecimal depreciacionAcumulada,
            BigDecimal valorEnLibros
    ) {}
}
