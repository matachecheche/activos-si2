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
}
