package com.uagrm.activos.ia;

import java.util.List;
import java.util.Map;

public record ResultadoConsulta(String sql, List<String> columnas, List<Map<String, Object>> filas) {
}
