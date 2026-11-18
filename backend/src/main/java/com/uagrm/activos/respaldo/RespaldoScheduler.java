package com.uagrm.activos.respaldo;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** HU-16: revisa cada hora si hay respaldos programados pendientes. */
@Component
public class RespaldoScheduler {

    private final RespaldoService respaldoService;

    public RespaldoScheduler(RespaldoService respaldoService) {
        this.respaldoService = respaldoService;
    }

    @Scheduled(cron = "${app.respaldos.cron:0 5 * * * *}")
    public void revisar() {
        respaldoService.ejecutarProgramados();
    }
}
