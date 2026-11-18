package com.uagrm.activos.domain;

import com.uagrm.activos.model.EstadoActivo;
import org.junit.jupiter.api.Test;

import java.util.EnumSet;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Transiciones de la Figura 11 del perfil. */
class ReglasEstadoActivoTest {

    @Test
    void transicionesPermitidas() {
        assertTrue(ReglasEstadoActivo.permitida(EstadoActivo.DISPONIBLE, EstadoActivo.EN_USO));
        assertTrue(ReglasEstadoActivo.permitida(EstadoActivo.EN_USO, EstadoActivo.DISPONIBLE));
        assertTrue(ReglasEstadoActivo.permitida(EstadoActivo.DISPONIBLE, EstadoActivo.INACTIVO));
        assertTrue(ReglasEstadoActivo.permitida(EstadoActivo.INACTIVO, EstadoActivo.DISPONIBLE));
        assertTrue(ReglasEstadoActivo.permitida(EstadoActivo.EN_USO, EstadoActivo.EN_MANTENIMIENTO));
        assertTrue(ReglasEstadoActivo.permitida(EstadoActivo.EN_MANTENIMIENTO, EstadoActivo.EN_USO));
        assertTrue(ReglasEstadoActivo.permitida(EstadoActivo.DADO_DE_BAJA, EstadoActivo.DISPONIBLE));
    }

    @Test
    void darDeBajaSePuedeDesdeCualquierEstadoVigente() {
        for (EstadoActivo estado : EnumSet.of(EstadoActivo.DISPONIBLE, EstadoActivo.EN_USO,
                EstadoActivo.EN_MANTENIMIENTO, EstadoActivo.INACTIVO)) {
            assertTrue(ReglasEstadoActivo.permitida(estado, EstadoActivo.DADO_DE_BAJA), estado.name());
        }
    }

    @Test
    void unActivoDadoDeBajaSoloPuedeReactivarseComoDisponible() {
        assertFalse(ReglasEstadoActivo.permitida(EstadoActivo.DADO_DE_BAJA, EstadoActivo.EN_USO));
        assertFalse(ReglasEstadoActivo.permitida(EstadoActivo.DADO_DE_BAJA, EstadoActivo.INACTIVO));
        assertFalse(ReglasEstadoActivo.permitida(EstadoActivo.DADO_DE_BAJA, EstadoActivo.EN_MANTENIMIENTO));
    }

    @Test
    void transicionesNoDefinidas() {
        assertFalse(ReglasEstadoActivo.permitida(EstadoActivo.INACTIVO, EstadoActivo.EN_USO));
        assertFalse(ReglasEstadoActivo.permitida(EstadoActivo.EN_USO, EstadoActivo.INACTIVO));
        assertFalse(ReglasEstadoActivo.permitida(null, EstadoActivo.DISPONIBLE));
    }

    @Test
    void destinosManualesNoIncluyenEnUsoNiEnMantenimiento() {
        assertEquals(EnumSet.of(EstadoActivo.INACTIVO, EstadoActivo.DADO_DE_BAJA),
                ReglasEstadoActivo.destinosManuales(EstadoActivo.DISPONIBLE));
        assertEquals(EnumSet.of(EstadoActivo.DISPONIBLE, EstadoActivo.DADO_DE_BAJA),
                ReglasEstadoActivo.destinosManuales(EstadoActivo.EN_USO));
        assertEquals(EnumSet.of(EstadoActivo.DADO_DE_BAJA),
                ReglasEstadoActivo.destinosManuales(EstadoActivo.EN_MANTENIMIENTO));
        assertEquals(EnumSet.of(EstadoActivo.DISPONIBLE),
                ReglasEstadoActivo.destinosManuales(EstadoActivo.DADO_DE_BAJA));
    }

    @Test
    void losEstadosDeSprint1SeSiguenLeyendo() {
        assertEquals(EstadoActivo.DISPONIBLE, EstadoActivo.desdeTexto("SIN_ASIGNAR"));
        assertEquals(EstadoActivo.EN_MANTENIMIENTO, EstadoActivo.desdeTexto("MANTENIMIENTO"));
        assertEquals(EstadoActivo.DADO_DE_BAJA, EstadoActivo.desdeTexto("BAJA"));
        assertEquals(EstadoActivo.EN_USO, EstadoActivo.desdeTexto("en_uso"));
    }
}
