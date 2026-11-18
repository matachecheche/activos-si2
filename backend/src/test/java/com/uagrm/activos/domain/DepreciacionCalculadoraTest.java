package com.uagrm.activos.domain;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** CP-06 del perfil: equipo de computacion de Bs 6.000, vida util 4 anios, sin valor residual. */
class DepreciacionCalculadoraTest {

    private final DepreciacionCalculadora.Estrategia lineaRecta = DepreciacionCalculadora.estrategia("LINEA_RECTA");

    private static BigDecimal bd(String valor) {
        return new BigDecimal(valor);
    }

    @Test
    void equipoDeComputacionSeDepreciaEnCuatroAnios() {
        List<DepreciacionCalculadora.Fila> filas = lineaRecta.calcular(bd("6000.00"), bd("0.00"), 48,
                YearMonth.of(2026, 1), YearMonth.of(2040, 12));

        assertEquals(48, filas.size(), "la depreciacion termina al agotarse la vida util");
        assertEquals(bd("125.00"), filas.get(0).depreciacionPeriodo());
        assertEquals(bd("1500.00"), filas.get(11).depreciacionAcumulada());
        assertEquals(bd("4500.00"), filas.get(11).valorEnLibros());
        assertEquals(bd("3000.00"), filas.get(23).valorEnLibros());
        assertEquals(bd("6000.00"), filas.get(47).depreciacionAcumulada());
        assertEquals(bd("0.00"), filas.get(47).valorEnLibros());
        assertEquals("2029-12", filas.get(47).periodo());
    }

    @Test
    void noGeneraPeriodosPosterioresAlLimiteSolicitado() {
        List<DepreciacionCalculadora.Fila> filas = lineaRecta.calcular(bd("6000.00"), bd("0.00"), 48,
                YearMonth.of(2026, 1), YearMonth.of(2026, 3));
        assertEquals(3, filas.size());
        assertEquals("2026-03", filas.get(2).periodo());
    }

    @Test
    void elUltimoMesAjustaElRedondeo() {
        List<DepreciacionCalculadora.Fila> filas = lineaRecta.calcular(bd("1000.00"), bd("0.00"), 3,
                YearMonth.of(2026, 1), YearMonth.of(2026, 12));
        assertEquals(bd("333.33"), filas.get(0).depreciacionPeriodo());
        assertEquals(bd("333.34"), filas.get(2).depreciacionPeriodo());
        assertEquals(bd("1000.00"), filas.get(2).depreciacionAcumulada());
        assertEquals(bd("0.00"), filas.get(2).valorEnLibros());
    }

    @Test
    void elValorEnLibrosNuncaBajaDelValorResidual() {
        List<DepreciacionCalculadora.Fila> filas = lineaRecta.calcular(bd("1000.00"), bd("100.00"), 12,
                YearMonth.of(2026, 1), YearMonth.of(2030, 1));
        assertEquals(12, filas.size());
        assertEquals(bd("75.00"), filas.get(0).depreciacionPeriodo());
        assertEquals(bd("100.00"), filas.get(11).valorEnLibros());
    }

    @Test
    void sinBaseDepreciableNoHayFilas() {
        assertTrue(lineaRecta.calcular(bd("500.00"), bd("500.00"), 12, YearMonth.of(2026, 1), YearMonth.of(2027, 1)).isEmpty());
        assertTrue(lineaRecta.calcular(bd("500.00"), bd("0.00"), 0, YearMonth.of(2026, 1), YearMonth.of(2027, 1)).isEmpty());
    }

    @Test
    void elMetodoPorDefectoEsLineaRectaYLosDemasSeRechazan() {
        assertEquals("LINEA_RECTA", DepreciacionCalculadora.estrategia(null).codigo());
        assertThrows(IllegalArgumentException.class, () -> DepreciacionCalculadora.estrategia("SALDOS_DECRECIENTES"));
    }
}
