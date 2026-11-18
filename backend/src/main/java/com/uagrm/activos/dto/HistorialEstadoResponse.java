package com.uagrm.activos.dto;

import java.time.LocalDateTime;

public record HistorialEstadoResponse(
        Long id,
        String estadoAnterior,
        String estadoAnteriorEtiqueta,
        String estadoNuevo,
        String estadoNuevoEtiqueta,
        String motivo,
        String usuario,
        LocalDateTime fecha
) {}
