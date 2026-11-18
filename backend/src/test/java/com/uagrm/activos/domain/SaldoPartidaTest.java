package com.uagrm.activos.domain;

import com.uagrm.activos.model.EjecucionPresupuestaria;
import com.uagrm.activos.model.TipoEjecucion;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** CP-12 del perfil: saldo disponible = planificado - (comprometido + ejecutado). */
class SaldoPartidaTest {

    private static BigDecimal bd(String valor) {
        return new BigDecimal(valor);
    }

    private static EjecucionPresupuestaria mov(Long id, TipoEjecucion tipo, String monto, EjecucionPresupuestaria compromiso) {
        return EjecucionPresupuestaria.builder().id(id).tipo(tipo).monto(bd(monto)).compromiso(compromiso).build();
    }

    @Test
    void sinMovimientosTodoElPlanEstaDisponible() {
        SaldoPartida s = SaldoPartida.calcular(bd("10000"), List.of());
        assertEquals(bd("10000.00"), s.saldoDisponible());
        assertEquals(bd("0.00"), s.porcentajeEjecucion());
    }

    @Test
    void compromisosYEjecucionesRestanDelSaldo() {
        SaldoPartida s = SaldoPartida.calcular(bd("10000"), List.of(
                mov(1L, TipoEjecucion.COMPROMISO, "2000", null),
                mov(2L, TipoEjecucion.EJECUCION, "3000", null)));
        assertEquals(bd("2000.00"), s.comprometido());
        assertEquals(bd("3000.00"), s.ejecutado());
        assertEquals(bd("5000.00"), s.saldoDisponible());
        assertEquals(bd("30.00"), s.porcentajeEjecucion());
    }

    @Test
    void ejecutarUnCompromisoLoLiberaYNoDuplicaElMonto() {
        EjecucionPresupuestaria compromiso = mov(1L, TipoEjecucion.COMPROMISO, "2000", null);
        EjecucionPresupuestaria ejecucion = mov(2L, TipoEjecucion.EJECUCION, "1900", compromiso);
        SaldoPartida s = SaldoPartida.calcular(bd("10000"), List.of(compromiso, ejecucion));
        assertEquals(bd("0.00"), s.comprometido());
        assertEquals(bd("1900.00"), s.ejecutado());
        assertEquals(bd("8100.00"), s.saldoDisponible());
    }
}
