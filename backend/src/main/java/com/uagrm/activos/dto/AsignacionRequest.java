package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotNull;

public record AsignacionRequest(
        @NotNull(message = "El activo es obligatorio") Long activoId,
        @NotNull(message = "El responsable es obligatorio") Long responsableId,
        @NotNull(message = "La ubicación es obligatoria") Long ubicacionId
) {}
