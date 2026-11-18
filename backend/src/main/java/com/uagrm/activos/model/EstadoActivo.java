package com.uagrm.activos.model;

/**
 * HU-06: estados permitidos del activo (Figura 11 del perfil).
 * Los valores historicos de Sprint 1 (SIN_ASIGNAR, MANTENIMIENTO, BAJA) se siguen
 * leyendo gracias a {@link #desdeTexto(String)}.
 */
public enum EstadoActivo {
    DISPONIBLE("Disponible"),
    EN_USO("En uso"),
    EN_MANTENIMIENTO("En mantenimiento"),
    INACTIVO("Inactivo"),
    DADO_DE_BAJA("Dado de baja");

    private final String etiqueta;

    EstadoActivo(String etiqueta) {
        this.etiqueta = etiqueta;
    }

    public String getEtiqueta() {
        return etiqueta;
    }

    public static EstadoActivo desdeTexto(String texto) {
        if (texto == null) {
            return null;
        }
        String valor = texto.trim().toUpperCase();
        switch (valor) {
            case "SIN_ASIGNAR":
                return DISPONIBLE;
            case "MANTENIMIENTO":
                return EN_MANTENIMIENTO;
            case "BAJA":
                return DADO_DE_BAJA;
            default:
                return EstadoActivo.valueOf(valor);
        }
    }
}
