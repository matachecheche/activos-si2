package com.uagrm.activos.ia;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

/** Especificacion de una consulta dinamica validada contra el catalogo whitelist. */
@JsonIgnoreProperties(ignoreUnknown = true)
public class ConsultaEspec {
    public String entidad;
    public List<String> columnas;
    public List<FiltroEspec> filtros;
    public List<OrdenEspec> orden;
    public Integer limite;
    public AgregacionEspec agregacion;

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class FiltroEspec {
        public String campo;
        public String operador;
        public Object valor;
        public Object valorHasta; // para BETWEEN
        public List<Object> valores; // para IN
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class OrdenEspec {
        public String campo;
        public String direccion; // ASC | DESC
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class AgregacionEspec {
        public String funcion;   // COUNT | SUM | AVG | MIN | MAX
        public String campo;     // "*" solo para COUNT
        public List<String> agruparPor;
    }
}
