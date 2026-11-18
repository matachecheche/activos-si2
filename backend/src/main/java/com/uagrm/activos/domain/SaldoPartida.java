package com.uagrm.activos.domain;

import com.uagrm.activos.model.EjecucionPresupuestaria;
import com.uagrm.activos.model.TipoEjecucion;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

/**
 * HU-10: saldo disponible = planificado - (comprometido + ejecutado).
 * Un compromiso que ya fue ejecutado (alguna ejecucion lo referencia) queda liberado y no
 * se vuelve a descontar del saldo.
 */
public record SaldoPartida(
        BigDecimal planificado,
        BigDecimal comprometido,
        BigDecimal ejecutado,
        BigDecimal saldoDisponible,
        BigDecimal porcentajeEjecucion
) {

    public static SaldoPartida calcular(BigDecimal planificado, Collection<EjecucionPresupuestaria> movimientos) {
        BigDecimal plan = escala(planificado);
        Set<Long> liberados = new HashSet<>();
        for (EjecucionPresupuestaria m : movimientos) {
            if (m.getTipo() == TipoEjecucion.EJECUCION && m.getCompromiso() != null) {
                liberados.add(m.getCompromiso().getId());
            }
        }
        BigDecimal comprometido = BigDecimal.ZERO;
        BigDecimal ejecutado = BigDecimal.ZERO;
        for (EjecucionPresupuestaria m : movimientos) {
            if (m.getTipo() == TipoEjecucion.EJECUCION) {
                ejecutado = ejecutado.add(m.getMonto());
            } else if (m.getTipo() == TipoEjecucion.COMPROMISO && !liberados.contains(m.getId())) {
                comprometido = comprometido.add(m.getMonto());
            }
        }
        return desdeMontos(plan, comprometido, ejecutado);
    }

    public static SaldoPartida desdeMontos(BigDecimal planificado, BigDecimal comprometido, BigDecimal ejecutado) {
        BigDecimal plan = escala(planificado);
        BigDecimal comp = escala(comprometido);
        BigDecimal ejec = escala(ejecutado);
        BigDecimal saldo = plan.subtract(comp).subtract(ejec);
        BigDecimal porcentaje = plan.signum() > 0
                ? ejec.multiply(BigDecimal.valueOf(100)).divide(plan, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO.setScale(2);
        return new SaldoPartida(plan, comp, ejec, saldo, porcentaje);
    }

    private static BigDecimal escala(BigDecimal valor) {
        return (valor == null ? BigDecimal.ZERO : valor).setScale(2, RoundingMode.HALF_UP);
    }
}
