package com.uagrm.activos.ia;

/** Una columna permitida: nombre fisico en BD, tipo y etiqueta en lenguaje natural. */
public record ColumnaCatalogo(String nombre, TipoColumna tipo, String etiqueta) {
}
