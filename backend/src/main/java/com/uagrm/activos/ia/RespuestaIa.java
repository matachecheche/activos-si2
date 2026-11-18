package com.uagrm.activos.ia;

import lombok.*;
import java.util.List;
import java.util.Map;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class RespuestaIa {
    private String modo;          // GROQ | GEMINI | GUIADO
    private String explicacion;   // respuesta en lenguaje natural
    private String sqlEjecutado;
    private List<String> columnas;
    private List<Map<String, Object>> filas;
    private List<String> sugerencias;
    private List<String> diagnostico;   // vacio si el LLM respondio; con el detalle si cayo a modo guiado
}
