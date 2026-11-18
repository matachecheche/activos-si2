package com.uagrm.activos.dto;

import jakarta.validation.constraints.Size;

public record MantenimientoCancelarRequest(
        @Size(max = 500, message = "El motivo admite hasta 500 caracteres") String motivo
) {}
