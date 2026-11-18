package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.domain.SaldoPartida;
import com.uagrm.activos.dto.EjecucionRequest;
import com.uagrm.activos.dto.EjecucionResponse;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.EjecucionPresupuestaria;
import com.uagrm.activos.model.EstadoPresupuesto;
import com.uagrm.activos.model.PartidaPresupuestaria;
import com.uagrm.activos.model.TipoEjecucion;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.EjecucionRepository;
import com.uagrm.activos.repository.PartidaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * HU-10: compromisos y ejecuciones por partida. El saldo se calcula dentro de la misma
 * transaccion que registra la operacion y la fila de la partida se bloquea para evitar que dos
 * operaciones simultaneas superen el monto planificado.
 */
@Service
public class EjecucionService {

    private final EjecucionRepository ejecucionRepository;
    private final PartidaRepository partidaRepository;
    private final ActivoRepository activoRepository;
    private final PresupuestoService presupuestoService;
    private final SesionService sesionService;

    public EjecucionService(EjecucionRepository ejecucionRepository,
                            PartidaRepository partidaRepository,
                            ActivoRepository activoRepository,
                            PresupuestoService presupuestoService,
                            SesionService sesionService) {
        this.ejecucionRepository = ejecucionRepository;
        this.partidaRepository = partidaRepository;
        this.activoRepository = activoRepository;
        this.presupuestoService = presupuestoService;
        this.sesionService = sesionService;
    }

    @Transactional
    @Auditable(accion = "REGISTRAR", entidad = "EJECUCION_PRESUPUESTARIA")
    public EjecucionResponse registrar(EjecucionRequest req) {
        PartidaPresupuestaria partida = partidaRepository.findByIdForUpdate(req.partidaId())
                .orElseThrow(() -> new IllegalArgumentException("Partida no encontrada"));
        EstadoPresupuesto estadoPresupuesto = partida.getPresupuesto().getEstado();
        if (estadoPresupuesto != EstadoPresupuesto.APROBADO) {
            throw new IllegalStateException("Solo se pueden registrar operaciones en presupuestos aprobados (estado actual: "
                    + estadoPresupuesto.name().toLowerCase() + ")");
        }
        Activo activo = null;
        if (req.activoId() != null) {
            activo = activoRepository.findById(req.activoId())
                    .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
        }

        List<EjecucionPresupuestaria> movimientos = ejecucionRepository.findByPartidaOrderByFechaDescIdDesc(partida);
        BigDecimal monto = req.monto().setScale(2, RoundingMode.HALF_UP);

        EjecucionPresupuestaria compromiso = null;
        if (req.compromisoId() != null) {
            if (req.tipo() != TipoEjecucion.EJECUCION) {
                throw new IllegalArgumentException("Solo una ejecución puede vincularse a un compromiso");
            }
            compromiso = ejecucionRepository.findById(req.compromisoId())
                    .orElseThrow(() -> new IllegalArgumentException("Compromiso no encontrado"));
            if (compromiso.getTipo() != TipoEjecucion.COMPROMISO) {
                throw new IllegalArgumentException("El movimiento indicado no es un compromiso");
            }
            if (!compromiso.getPartida().getId().equals(partida.getId())) {
                throw new IllegalArgumentException("El compromiso pertenece a otra partida");
            }
            if (compromisoLiberado(compromiso, movimientos)) {
                throw new IllegalStateException("El compromiso ya fue ejecutado");
            }
        }

        SaldoPartida saldo = SaldoPartida.calcular(partida.getMontoPlanificado(), movimientos);
        BigDecimal disponible = saldo.saldoDisponible();
        if (compromiso != null) {
            // al ejecutar un compromiso este se libera: su monto vuelve a estar disponible
            disponible = disponible.add(compromiso.getMonto());
        }
        if (monto.compareTo(disponible) > 0) {
            throw new IllegalStateException("Sobre ejecución: el monto (" + monto + ") supera el saldo disponible de la partida ("
                    + disponible + ")");
        }

        EjecucionPresupuestaria guardada = ejecucionRepository.save(EjecucionPresupuestaria.builder()
                .partida(partida)
                .fecha(req.fecha())
                .concepto(req.concepto().trim())
                .monto(monto)
                .tipo(req.tipo())
                .activo(activo)
                .compromiso(compromiso)
                .usuario(sesionService.usuarioActual())
                .build());
        return respuesta(guardada, false);
    }

    @Transactional(readOnly = true)
    public List<EjecucionResponse> listar(Long presupuestoId) {
        presupuestoService.entidad(presupuestoId);
        List<EjecucionPresupuestaria> movimientos = ejecucionRepository.findByPartida_Presupuesto_IdOrderByFechaDescIdDesc(presupuestoId);
        Set<Long> liberados = new HashSet<>();
        for (EjecucionPresupuestaria m : movimientos) {
            if (m.getTipo() == TipoEjecucion.EJECUCION && m.getCompromiso() != null) {
                liberados.add(m.getCompromiso().getId());
            }
        }
        return movimientos.stream()
                .map(m -> respuesta(m, m.getTipo() == TipoEjecucion.COMPROMISO && liberados.contains(m.getId())))
                .toList();
    }

    private boolean compromisoLiberado(EjecucionPresupuestaria compromiso, List<EjecucionPresupuestaria> movimientos) {
        for (EjecucionPresupuestaria m : movimientos) {
            if (m.getTipo() == TipoEjecucion.EJECUCION && m.getCompromiso() != null
                    && m.getCompromiso().getId().equals(compromiso.getId())) {
                return true;
            }
        }
        return false;
    }

    private EjecucionResponse respuesta(EjecucionPresupuestaria e, boolean liberado) {
        return new EjecucionResponse(
                e.getId(),
                e.getPartida().getId(),
                e.getPartida().getCodigo(),
                e.getPartida().getNombre(),
                e.getTipo().name(),
                e.getFecha(),
                e.getConcepto(),
                e.getMonto(),
                e.getActivo() == null ? null : e.getActivo().getId(),
                e.getActivo() == null ? null : e.getActivo().getCodigo(),
                e.getCompromiso() == null ? null : e.getCompromiso().getId(),
                liberado,
                e.getUsuario() == null ? null : e.getUsuario().getNombre());
    }
}
