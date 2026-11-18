package com.uagrm.activos.ia;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.util.List;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class PreguntaIaRequest {
    @NotBlank
    @Size(max = 1000)
    private String pregunta;

    /** Ultimos mensajes de la conversacion (opcional) para preguntas de seguimiento. */
    @Valid
    @Size(max = 10)
    private List<TurnoHistorial> historial;

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class TurnoHistorial {
        /** "usuario" o "asistente". */
        @NotBlank
        @Size(max = 12)
        private String rol;

        @NotBlank
        @Size(max = 1000)
        private String texto;
    }
}
