package com.uagrm.activos.dto;

import java.time.LocalDateTime;

public record AsignacionResponse(
        Long id,
        Long activoId,
        String activoCodigo,
        ActivoResponse.UsuarioRef responsable,
        ActivoResponse.UbicacionRef ubicacion,
        LocalDateTime fechaAsignacion,
        Boolean activa
) {}
