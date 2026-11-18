package com.uagrm.activos.dto;

import java.math.BigDecimal;

public record CategoriaResponse(
        Long id,
        String nombre,
        Integer vidaUtil,
        String metodoDepreciacion,
        BigDecimal valorResidualPct,
        Boolean depreciable
) {}
