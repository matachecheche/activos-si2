package com.uagrm.activos.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record EjecucionResponse(
        Long id,
        Long partidaId,
        String partidaCodigo,
        String partidaNombre,
        String tipo,
        LocalDate fecha,
        String concepto,
        BigDecimal monto,
        Long activoId,
        String activoCodigo,
        Long compromisoId,
        boolean liberado,
        String usuario
) {}
