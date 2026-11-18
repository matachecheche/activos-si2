package com.uagrm.activos.dto;

import com.uagrm.activos.model.EstadoActivo;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** HU-06: todo cambio de estado exige un motivo. */
public record CambioEstadoRequest(
        @NotNull(message = "El nuevo estado es obligatorio") EstadoActivo estado,
        @NotBlank(message = "Debe indicar el motivo del cambio de estado")
        @Size(max = 255, message = "El motivo admite hasta 255 caracteres") String motivo
) {}
