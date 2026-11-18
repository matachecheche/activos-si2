package com.uagrm.activos.domain;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * HU-07: calculo de la depreciacion. Encapsulado en una estrategia para poder agregar otros
 * metodos sin modificar el resto del sistema. Por ahora solo existe la linea recta:
 * (valor de adquisicion - valor residual) / vida util expresada en meses.
 */
public final class DepreciacionCalculadora {

    public static final String LINEA_RECTA = "LINEA_RECTA";

    private DepreciacionCalculadora() {
    }

    /** Una fila de la tabla de depreciacion (periodo con formato yyyy-MM). */
    public record Fila(String periodo, BigDecimal depreciacionPeriodo, BigDecimal depreciacionAcumulada, BigDecimal valorEnLibros) {
    }

    public interface Estrategia {
        String codigo();

        BigDecimal cuotaMensual(BigDecimal valor, BigDecimal residual, int vidaUtilMeses);

        /** Genera las filas desde {@code inicio} hasta {@code hasta} (sin pasar del fin de la vida util). */
        List<Fila> calcular(BigDecimal valor, BigDecimal residual, int vidaUtilMeses, YearMonth inicio, YearMonth hasta);
    }

    public static final class LineaRecta implements Estrategia {

        @Override
        public String codigo() {
            return LINEA_RECTA;
        }

        @Override
        public BigDecimal cuotaMensual(BigDecimal valor, BigDecimal residual, int vidaUtilMeses) {
            BigDecimal total = valor.subtract(residual);
            if (vidaUtilMeses <= 0 || total.signum() <= 0) {
                return BigDecimal.ZERO.setScale(2);
            }
            return total.divide(BigDecimal.valueOf(vidaUtilMeses), 2, RoundingMode.HALF_UP);
        }

        @Override
        public List<Fila> calcular(BigDecimal valor, BigDecimal residual, int vidaUtilMeses, YearMonth inicio, YearMonth hasta) {
            List<Fila> filas = new ArrayList<>();
            BigDecimal total = valor.subtract(residual).setScale(2, RoundingMode.HALF_UP);
            if (vidaUtilMeses <= 0 || total.signum() <= 0) {
                return filas;
            }
            BigDecimal cuota = cuotaMensual(valor, residual, vidaUtilMeses);
            YearMonth fin = inicio.plusMonths(vidaUtilMeses - 1L);
            YearMonth tope = hasta.isBefore(fin) ? hasta : fin;
            BigDecimal anterior = BigDecimal.ZERO.setScale(2);
            int numero = 0;
            for (YearMonth periodo = inicio; !periodo.isAfter(tope); periodo = periodo.plusMonths(1)) {
                numero++;
                // el ultimo mes ajusta el redondeo para que la depreciacion total sea exacta
                BigDecimal acumulada = numero >= vidaUtilMeses
                        ? total
                        : cuota.multiply(BigDecimal.valueOf(numero)).min(total);
                BigDecimal delPeriodo = acumulada.subtract(anterior);
                BigDecimal enLibros = valor.setScale(2, RoundingMode.HALF_UP).subtract(acumulada);
                filas.add(new Fila(periodo.toString(), delPeriodo, acumulada, enLibros));
                anterior = acumulada;
            }
            return filas;
        }
    }

    private static final Map<String, Estrategia> ESTRATEGIAS = Map.of(LINEA_RECTA, new LineaRecta());

    public static Estrategia estrategia(String metodo) {
        String clave = (metodo == null || metodo.isBlank()) ? LINEA_RECTA : metodo.trim().toUpperCase();
        Estrategia estrategia = ESTRATEGIAS.get(clave);
        if (estrategia == null) {
            throw new IllegalArgumentException("Método de depreciación no soportado: " + metodo);
        }
        return estrategia;
    }
}
