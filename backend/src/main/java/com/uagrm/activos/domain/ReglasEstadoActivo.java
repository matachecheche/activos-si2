package com.uagrm.activos.domain;

import com.uagrm.activos.model.EstadoActivo;

import java.util.EnumMap;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

/** HU-06: transiciones permitidas entre estados del activo (Figura 11 del perfil). */
public final class ReglasEstadoActivo {

    private static final Map<EstadoActivo, Set<EstadoActivo>> TRANSICIONES = new EnumMap<>(EstadoActivo.class);

    static {
        TRANSICIONES.put(EstadoActivo.DISPONIBLE,
                EnumSet.of(EstadoActivo.EN_USO, EstadoActivo.INACTIVO, EstadoActivo.EN_MANTENIMIENTO, EstadoActivo.DADO_DE_BAJA));
        TRANSICIONES.put(EstadoActivo.EN_USO,
                EnumSet.of(EstadoActivo.DISPONIBLE, EstadoActivo.EN_MANTENIMIENTO, EstadoActivo.DADO_DE_BAJA));
        TRANSICIONES.put(EstadoActivo.EN_MANTENIMIENTO,
                EnumSet.of(EstadoActivo.DISPONIBLE, EstadoActivo.EN_USO, EstadoActivo.DADO_DE_BAJA));
        TRANSICIONES.put(EstadoActivo.INACTIVO,
                EnumSet.of(EstadoActivo.DISPONIBLE, EstadoActivo.DADO_DE_BAJA));
        TRANSICIONES.put(EstadoActivo.DADO_DE_BAJA,
                EnumSet.of(EstadoActivo.DISPONIBLE));
    }

    private ReglasEstadoActivo() {
    }

    public static boolean permitida(EstadoActivo desde, EstadoActivo hacia) {
        if (desde == null || hacia == null) {
            return false;
        }
        return TRANSICIONES.getOrDefault(desde, EnumSet.noneOf(EstadoActivo.class)).contains(hacia);
    }

    /**
     * Estados que el usuario puede elegir manualmente. "En uso" se alcanza asignando el activo y
     * "En mantenimiento" iniciando un mantenimiento, por lo que no se ofrecen aqui.
     */
    public static Set<EstadoActivo> destinosManuales(EstadoActivo desde) {
        Set<EstadoActivo> destinos = EnumSet.noneOf(EstadoActivo.class);
        if (desde == null) {
            return destinos;
        }
        for (EstadoActivo candidato : EnumSet.of(EstadoActivo.DISPONIBLE, EstadoActivo.INACTIVO, EstadoActivo.DADO_DE_BAJA)) {
            if (permitida(desde, candidato)) {
                destinos.add(candidato);
            }
        }
        if (desde == EstadoActivo.EN_MANTENIMIENTO) {
            // mientras hay un mantenimiento en ejecucion solo se puede dar de baja
            destinos.retainAll(EnumSet.of(EstadoActivo.DADO_DE_BAJA));
        }
        return destinos;
    }
}
