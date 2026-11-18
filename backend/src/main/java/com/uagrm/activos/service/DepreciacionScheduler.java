package com.uagrm.activos.service;

import com.uagrm.activos.dto.CalculoDepreciacionResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.YearMonth;

/** HU-07: proceso programado mensual (por defecto el dia 1 de cada mes a las 02:00). */
@Component
public class DepreciacionScheduler {

    private static final Logger log = LoggerFactory.getLogger(DepreciacionScheduler.class);

    private final DepreciacionService depreciacionService;

    public DepreciacionScheduler(DepreciacionService depreciacionService) {
        this.depreciacionService = depreciacionService;
    }

    @Scheduled(cron = "${app.depreciacion.cron:0 0 2 1 * *}")
    public void calcularMensual() {
        try {
            CalculoDepreciacionResponse r = depreciacionService.calcularTodos(YearMonth.now());
            log.info("Depreciación mensual hasta {}: {} activos, {} periodos nuevos", r.hasta(), r.activosProcesados(), r.periodosGenerados());
        } catch (Exception e) {
            log.error("Falló el cálculo mensual de depreciación", e);
        }
    }

    /**
     * Red de seguridad: cada hora se comprueba si falta el periodo de
     * depreciacion del mes en curso y, si es asi, se calcula.
     *
     * <p>Hace falta porque los datos de fabrica se siembran DESPUES de que el
     * backend arranca: el calculo del arranque todavia no encuentra activos y
     * la pantalla de depreciacion se quedaria vacia hasta el dia 1 del mes
     * siguiente. El calculo es idempotente (los periodos existentes se
     * respetan), asi que se puede repetir sin miedo.</p>
     */
    @Scheduled(cron = "${app.depreciacion.cron-referencia:0 20 * * * *}")
    public void completarPeriodoActual() {
        try {
            if (!depreciacionService.faltaPeriodoActual(YearMonth.now())) {
                return;
            }
            CalculoDepreciacionResponse r = depreciacionService.calcularTodos(YearMonth.now());
            if (r.periodosGenerados() > 0) {
                log.info("Depreciación del mes completada: {} periodos nuevos (pantalla siempre con datos)",
                        r.periodosGenerados());
            }
        } catch (Exception e) {
            log.warn("No se pudo completar la depreciación del mes: {}", e.getMessage());
        }
    }
}
