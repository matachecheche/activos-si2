package com.uagrm.activos.ia;

import java.util.List;
import java.util.Map;
import java.util.LinkedHashMap;

/** Entidad consultable: tabla fisica, descripcion y columnas whitelist. */
public record TablaCatalogo(String tabla, String etiqueta, String descripcion, List<ColumnaCatalogo> columnas) {

    public Map<String, ColumnaCatalogo> mapaColumnas() {
        Map<String, ColumnaCatalogo> mapa = new LinkedHashMap<>();
        for (ColumnaCatalogo c : columnas) {
            mapa.put(c.nombre(), c);
        }
        return mapa;
    }
}
