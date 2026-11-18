package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.domain.SaldoPartida;
import com.uagrm.activos.dto.PartidaRequest;
import com.uagrm.activos.dto.PartidaResponse;
import com.uagrm.activos.dto.PresupuestoRequest;
import com.uagrm.activos.dto.PresupuestoResponse;
import com.uagrm.activos.dto.SeguimientoResponse;
import com.uagrm.activos.model.Area;
import com.uagrm.activos.model.EjecucionPresupuestaria;
import com.uagrm.activos.model.EstadoPresupuesto;
import com.uagrm.activos.model.PartidaPresupuestaria;
import com.uagrm.activos.model.Presupuesto;
import com.uagrm.activos.repository.AreaRepository;
import com.uagrm.activos.repository.EjecucionRepository;
import com.uagrm.activos.repository.PartidaRepository;
import com.uagrm.activos.repository.PresupuestoRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** HU-09: presupuesto anual por gestion y area, con partidas, aprobacion y cierre. */
@Service
public class PresupuestoService {

    private final PresupuestoRepository presupuestoRepository;
    private final PartidaRepository partidaRepository;
    private final EjecucionRepository ejecucionRepository;
    private final AreaRepository areaRepository;
    private final SesionService sesionService;

    public PresupuestoService(PresupuestoRepository presupuestoRepository,
                              PartidaRepository partidaRepository,
                              EjecucionRepository ejecucionRepository,
                              AreaRepository areaRepository,
                              SesionService sesionService) {
        this.presupuestoRepository = presupuestoRepository;
        this.partidaRepository = partidaRepository;
        this.ejecucionRepository = ejecucionRepository;
        this.areaRepository = areaRepository;
        this.sesionService = sesionService;
    }

    @Transactional(readOnly = true)
    public List<PresupuestoResponse> listar(Integer gestion, Long areaId) {
        return presupuestoRepository.findAllByOrderByGestionDescIdDesc().stream()
                .filter(p -> gestion == null || p.getGestion().equals(gestion))
                .filter(p -> areaId == null || p.getArea().getId().equals(areaId))
                .map(p -> construir(p).presupuesto())
                .toList();
    }

    @Transactional(readOnly = true)
    public PresupuestoResponse obtener(Long id) {
        return construir(entidad(id)).presupuesto();
    }

    @Transactional(readOnly = true)
    public SeguimientoResponse seguimiento(Long id) {
        return construir(entidad(id));
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "PRESUPUESTO")
    public PresupuestoResponse crear(PresupuestoRequest req) {
        Area area = area(req.areaId());
        if (presupuestoRepository.existsByAreaAndGestion(area, req.gestion())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "El área " + area.getNombre() + " ya tiene un presupuesto para la gestión " + req.gestion());
        }
        Presupuesto p = Presupuesto.builder()
                .area(area)
                .gestion(req.gestion())
                .montoAprobado(req.montoAprobado().setScale(2, RoundingMode.HALF_UP))
                .estado(EstadoPresupuesto.BORRADOR)
                .build();
        return construir(presupuestoRepository.save(p)).presupuesto();
    }

    @Transactional
    @Auditable(accion = "EDITAR", entidad = "PRESUPUESTO", idExpresion = "#a0")
    public PresupuestoResponse actualizar(Long id, PresupuestoRequest req) {
        Presupuesto p = entidad(id);
        exigirBorrador(p);
        Area area = area(req.areaId());
        boolean cambioClave = !p.getArea().getId().equals(area.getId()) || !p.getGestion().equals(req.gestion());
        if (cambioClave && presupuestoRepository.existsByAreaAndGestion(area, req.gestion())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "El área " + area.getNombre() + " ya tiene un presupuesto para la gestión " + req.gestion());
        }
        BigDecimal monto = req.montoAprobado().setScale(2, RoundingMode.HALF_UP);
        BigDecimal planificado = sumaPartidas(p);
        if (planificado.compareTo(monto) > 0) {
            throw new IllegalStateException("El monto aprobado no puede ser menor a la suma de las partidas (" + planificado + ")");
        }
        p.setArea(area);
        p.setGestion(req.gestion());
        p.setMontoAprobado(monto);
        return construir(presupuestoRepository.save(p)).presupuesto();
    }

    @Transactional
    @Auditable(accion = "APROBAR", entidad = "PRESUPUESTO", idExpresion = "#a0")
    public PresupuestoResponse aprobar(Long id) {
        Presupuesto p = entidad(id);
        exigirBorrador(p);
        if (sumaPartidas(p).compareTo(p.getMontoAprobado()) > 0) {
            throw new IllegalStateException("La suma de las partidas supera el monto aprobado");
        }
        p.setEstado(EstadoPresupuesto.APROBADO);
        p.setFechaAprobacion(LocalDateTime.now());
        p.setUsuarioAprobador(sesionService.usuarioActual());
        return construir(presupuestoRepository.save(p)).presupuesto();
    }

    @Transactional
    @Auditable(accion = "CERRAR", entidad = "PRESUPUESTO", idExpresion = "#a0")
    public PresupuestoResponse cerrar(Long id) {
        Presupuesto p = entidad(id);
        if (p.getEstado() != EstadoPresupuesto.APROBADO) {
            throw new IllegalStateException("Solo un presupuesto aprobado puede cerrarse al finalizar la gestión");
        }
        p.setEstado(EstadoPresupuesto.CERRADO);
        return construir(presupuestoRepository.save(p)).presupuesto();
    }

    @Transactional
    public void eliminar(Long id) {
        Presupuesto p = entidad(id);
        exigirBorrador(p);
        partidaRepository.deleteAll(partidaRepository.findByPresupuestoOrderByCodigoAsc(p));
        presupuestoRepository.delete(p);
    }

    // ---- partidas ----

    @Transactional(readOnly = true)
    public List<PartidaResponse> partidas(Long presupuestoId) {
        return construir(entidad(presupuestoId)).partidas();
    }

    @Transactional
    public PartidaResponse crearPartida(Long presupuestoId, PartidaRequest req) {
        Presupuesto p = entidad(presupuestoId);
        exigirBorrador(p);
        String codigo = req.codigo().trim();
        if (partidaRepository.existsByPresupuestoAndCodigoIgnoreCase(p, codigo)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe una partida con el código " + codigo);
        }
        BigDecimal monto = req.montoPlanificado().setScale(2, RoundingMode.HALF_UP);
        validarSuma(p, sumaPartidas(p).add(monto));
        PartidaPresupuestaria partida = partidaRepository.save(PartidaPresupuestaria.builder()
                .presupuesto(p).codigo(codigo).nombre(req.nombre().trim()).montoPlanificado(monto).build());
        return partidaRespuesta(partida, SaldoPartida.desdeMontos(monto, BigDecimal.ZERO, BigDecimal.ZERO));
    }

    @Transactional
    public PartidaResponse actualizarPartida(Long presupuestoId, Long partidaId, PartidaRequest req) {
        Presupuesto p = entidad(presupuestoId);
        exigirBorrador(p);
        PartidaPresupuestaria partida = partida(p, partidaId);
        String codigo = req.codigo().trim();
        if (!partida.getCodigo().equalsIgnoreCase(codigo) && partidaRepository.existsByPresupuestoAndCodigoIgnoreCase(p, codigo)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe una partida con el código " + codigo);
        }
        BigDecimal monto = req.montoPlanificado().setScale(2, RoundingMode.HALF_UP);
        validarSuma(p, sumaPartidas(p).subtract(partida.getMontoPlanificado()).add(monto));
        partida.setCodigo(codigo);
        partida.setNombre(req.nombre().trim());
        partida.setMontoPlanificado(monto);
        partida = partidaRepository.save(partida);
        return partidaRespuesta(partida, SaldoPartida.desdeMontos(monto, BigDecimal.ZERO, BigDecimal.ZERO));
    }

    @Transactional
    public void eliminarPartida(Long presupuestoId, Long partidaId) {
        Presupuesto p = entidad(presupuestoId);
        exigirBorrador(p);
        PartidaPresupuestaria partida = partida(p, partidaId);
        if (ejecucionRepository.existsByPartida(partida)) {
            throw new IllegalStateException("La partida tiene operaciones registradas y no puede eliminarse");
        }
        partidaRepository.delete(partida);
    }

    // ---- ejecuciones (consulta) ----

    @Transactional(readOnly = true)
    public Presupuesto entidad(Long id) {
        return presupuestoRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Presupuesto no encontrado"));
    }

    // ---- auxiliares ----

    private void exigirBorrador(Presupuesto p) {
        if (p.getEstado() != EstadoPresupuesto.BORRADOR) {
            throw new IllegalStateException("Un presupuesto aprobado o cerrado no puede modificarse");
        }
    }

    private void validarSuma(Presupuesto p, BigDecimal nuevaSuma) {
        if (nuevaSuma.compareTo(p.getMontoAprobado()) > 0) {
            throw new IllegalStateException("La suma de las partidas (" + nuevaSuma + ") supera el monto aprobado ("
                    + p.getMontoAprobado() + ")");
        }
    }

    private BigDecimal sumaPartidas(Presupuesto p) {
        BigDecimal total = BigDecimal.ZERO.setScale(2);
        for (PartidaPresupuestaria partida : partidaRepository.findByPresupuestoOrderByCodigoAsc(p)) {
            total = total.add(partida.getMontoPlanificado());
        }
        return total;
    }

    private PartidaPresupuestaria partida(Presupuesto p, Long partidaId) {
        PartidaPresupuestaria partida = partidaRepository.findById(partidaId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Partida no encontrada"));
        if (!partida.getPresupuesto().getId().equals(p.getId())) {
            throw new IllegalArgumentException("La partida no pertenece al presupuesto indicado");
        }
        return partida;
    }

    private Area area(Long id) {
        Area area = areaRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Área no encontrada"));
        if (Boolean.FALSE.equals(area.getActivo())) {
            throw new IllegalArgumentException("El área seleccionada está inactiva");
        }
        return area;
    }

    private PartidaResponse partidaRespuesta(PartidaPresupuestaria partida, SaldoPartida saldo) {
        return new PartidaResponse(partida.getId(), partida.getPresupuesto().getId(), partida.getCodigo(), partida.getNombre(),
                partida.getMontoPlanificado(), saldo.comprometido(), saldo.ejecutado(), saldo.saldoDisponible(),
                saldo.porcentajeEjecucion());
    }

    /** Planificado, comprometido, ejecutado y saldo por partida y para todo el presupuesto. */
    private SeguimientoResponse construir(Presupuesto p) {
        List<PartidaPresupuestaria> partidas = partidaRepository.findByPresupuestoOrderByCodigoAsc(p);
        Map<Long, List<EjecucionPresupuestaria>> porPartida = new HashMap<>();
        for (EjecucionPresupuestaria e : ejecucionRepository.findByPartida_Presupuesto_IdOrderByFechaDescIdDesc(p.getId())) {
            porPartida.computeIfAbsent(e.getPartida().getId(), k -> new ArrayList<>()).add(e);
        }
        List<PartidaResponse> respuestas = new ArrayList<>();
        BigDecimal planificado = BigDecimal.ZERO;
        BigDecimal comprometido = BigDecimal.ZERO;
        BigDecimal ejecutado = BigDecimal.ZERO;
        for (PartidaPresupuestaria partida : partidas) {
            SaldoPartida saldo = SaldoPartida.calcular(partida.getMontoPlanificado(),
                    porPartida.getOrDefault(partida.getId(), List.of()));
            respuestas.add(partidaRespuesta(partida, saldo));
            planificado = planificado.add(saldo.planificado());
            comprometido = comprometido.add(saldo.comprometido());
            ejecutado = ejecutado.add(saldo.ejecutado());
        }
        SaldoPartida total = SaldoPartida.desdeMontos(planificado, comprometido, ejecutado);
        PresupuestoResponse resumen = new PresupuestoResponse(
                p.getId(),
                p.getArea().getId(),
                p.getArea().getNombre(),
                p.getGestion(),
                p.getMontoAprobado(),
                p.getEstado().name(),
                p.getFechaAprobacion(),
                p.getUsuarioAprobador() == null ? null : p.getUsuarioAprobador().getNombre(),
                total.planificado(),
                p.getMontoAprobado().subtract(total.planificado()),
                total.comprometido(),
                total.ejecutado(),
                total.saldoDisponible(),
                total.porcentajeEjecucion());
        return new SeguimientoResponse(resumen, respuestas);
    }
}
