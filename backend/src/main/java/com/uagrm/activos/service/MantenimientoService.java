package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.dto.AlertasMantenimientoResponse;
import com.uagrm.activos.dto.MantenimientoActivoResponse;
import com.uagrm.activos.dto.MantenimientoCancelarRequest;
import com.uagrm.activos.dto.MantenimientoFinalizarRequest;
import com.uagrm.activos.dto.MantenimientoRequest;
import com.uagrm.activos.dto.MantenimientoResponse;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.model.EstadoMantenimiento;
import com.uagrm.activos.model.Mantenimiento;
import com.uagrm.activos.model.TipoMantenimiento;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.MantenimientoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * HU-08: programacion, ejecucion, cierre y cancelacion de mantenimientos.
 * El estado del activo cambia unicamente a traves de EstadoActivoService.
 */
@Service
public class MantenimientoService {

    private static final int DIAS_ALERTA = 7;

    private final MantenimientoRepository mantenimientoRepository;
    private final ActivoRepository activoRepository;
    private final EstadoActivoService estadoActivoService;
    private final SesionService sesionService;

    public MantenimientoService(MantenimientoRepository mantenimientoRepository,
                                ActivoRepository activoRepository,
                                EstadoActivoService estadoActivoService,
                                SesionService sesionService) {
        this.mantenimientoRepository = mantenimientoRepository;
        this.activoRepository = activoRepository;
        this.estadoActivoService = estadoActivoService;
        this.sesionService = sesionService;
    }

    @Transactional
    @Auditable(accion = "PROGRAMAR", entidad = "MANTENIMIENTO")
    public MantenimientoResponse programar(MantenimientoRequest req) {
        Activo activo = activo(req.activoId());
        if (activo.getEstado() == EstadoActivo.DADO_DE_BAJA) {
            throw new IllegalStateException("No se puede programar un mantenimiento para un activo dado de baja");
        }
        Mantenimiento m = Mantenimiento.builder()
                .activo(activo)
                .tipo(req.tipo())
                .estado(EstadoMantenimiento.PROGRAMADO)
                .fechaCreacion(LocalDateTime.now())
                .creadoPor(sesionService.usuarioActual())
                .build();
        completarDatos(m, req);
        return respuesta(mantenimientoRepository.save(m));
    }

    @Transactional
    @Auditable(accion = "EDITAR", entidad = "MANTENIMIENTO", idExpresion = "#a0")
    public MantenimientoResponse actualizar(Long id, MantenimientoRequest req) {
        Mantenimiento m = obtener(id);
        if (m.getEstado() != EstadoMantenimiento.PROGRAMADO) {
            throw new IllegalStateException("Solo se puede modificar un mantenimiento programado");
        }
        m.setTipo(req.tipo());
        completarDatos(m, req);
        return respuesta(mantenimientoRepository.save(m));
    }

    private void completarDatos(Mantenimiento m, MantenimientoRequest req) {
        String descripcion = req.descripcion() == null ? "" : req.descripcion().trim();
        if (req.tipo() == TipoMantenimiento.PREVENTIVO) {
            if (req.fechaProgramada() == null) {
                throw new IllegalArgumentException("Debe indicar la fecha programada del mantenimiento preventivo");
            }
            m.setFechaProgramada(req.fechaProgramada());
            m.setPeriodicidadDias(req.periodicidadDias());
        } else {
            if (descripcion.isEmpty()) {
                throw new IllegalArgumentException("Debe describir la falla del mantenimiento correctivo");
            }
            m.setFechaProgramada(req.fechaProgramada() != null ? req.fechaProgramada() : LocalDate.now());
            m.setPeriodicidadDias(null);
        }
        m.setDescripcion(descripcion.isEmpty() ? null : descripcion);
    }

    @Transactional
    @Auditable(accion = "INICIAR", entidad = "MANTENIMIENTO", idExpresion = "#a0")
    public MantenimientoResponse iniciar(Long id) {
        Mantenimiento m = obtener(id);
        if (m.getEstado() != EstadoMantenimiento.PROGRAMADO) {
            throw new IllegalStateException("Solo se puede iniciar un mantenimiento programado");
        }
        Activo activo = m.getActivo();
        EstadoActivo previo = activo.getEstado() == null ? EstadoActivo.DISPONIBLE : activo.getEstado();
        if (previo == EstadoActivo.DADO_DE_BAJA) {
            throw new IllegalStateException("No se puede iniciar un mantenimiento de un activo dado de baja");
        }
        if (mantenimientoRepository.existsByActivoAndEstado(activo, EstadoMantenimiento.EN_EJECUCION)) {
            throw new IllegalStateException("El activo ya tiene un mantenimiento en ejecución");
        }
        if (previo != EstadoActivo.DISPONIBLE && previo != EstadoActivo.EN_USO) {
            throw new IllegalStateException("Solo se puede iniciar mantenimiento en activos Disponibles o En uso (estado actual: "
                    + previo.getEtiqueta() + ")");
        }
        m.setEstadoPrevioActivo(previo);
        m.setEstado(EstadoMantenimiento.EN_EJECUCION);
        m.setFechaInicio(LocalDateTime.now());
        mantenimientoRepository.save(m);
        estadoActivoService.aplicarInterno(activo, EstadoActivo.EN_MANTENIMIENTO,
                "Inicio de mantenimiento " + m.getTipo().name().toLowerCase() + " #" + m.getId(), sesionService.usuarioActual());
        return respuesta(m);
    }

    @Transactional
    @Auditable(accion = "FINALIZAR", entidad = "MANTENIMIENTO", idExpresion = "#a0")
    public MantenimientoResponse finalizar(Long id, MantenimientoFinalizarRequest req) {
        Mantenimiento m = obtener(id);
        if (m.getEstado() != EstadoMantenimiento.EN_EJECUCION) {
            throw new IllegalStateException("Solo se puede finalizar un mantenimiento en ejecución");
        }
        LocalDate fecha = req.fechaRealizada() != null ? req.fechaRealizada() : LocalDate.now();
        m.setEstado(EstadoMantenimiento.FINALIZADO);
        m.setFechaRealizada(fecha);
        m.setCosto(req.costo().setScale(2, RoundingMode.HALF_UP));
        m.setTecnico(req.tecnico().trim());
        m.setObservaciones(req.observaciones() == null || req.observaciones().isBlank() ? null : req.observaciones().trim());
        mantenimientoRepository.save(m);
        restaurarEstadoActivo(m, "Fin del mantenimiento #" + m.getId() + ": retorna al estado previo");

        // HU-08: un preventivo con periodicidad programa automaticamente el siguiente
        if (m.getTipo() == TipoMantenimiento.PREVENTIVO && m.getPeriodicidadDias() != null) {
            mantenimientoRepository.save(Mantenimiento.builder()
                    .activo(m.getActivo())
                    .tipo(TipoMantenimiento.PREVENTIVO)
                    .estado(EstadoMantenimiento.PROGRAMADO)
                    .descripcion(m.getDescripcion())
                    .fechaProgramada(fecha.plusDays(m.getPeriodicidadDias()))
                    .periodicidadDias(m.getPeriodicidadDias())
                    .fechaCreacion(LocalDateTime.now())
                    .creadoPor(sesionService.usuarioActual())
                    .build());
        }
        return respuesta(m);
    }

    @Transactional
    @Auditable(accion = "CANCELAR", entidad = "MANTENIMIENTO", idExpresion = "#a0")
    public MantenimientoResponse cancelar(Long id, MantenimientoCancelarRequest req) {
        Mantenimiento m = obtener(id);
        if (m.getEstado() == EstadoMantenimiento.FINALIZADO || m.getEstado() == EstadoMantenimiento.CANCELADO) {
            throw new IllegalStateException("El mantenimiento ya está finalizado o cancelado");
        }
        boolean estabaEnEjecucion = m.getEstado() == EstadoMantenimiento.EN_EJECUCION;
        m.setEstado(EstadoMantenimiento.CANCELADO);
        if (req != null && req.motivo() != null && !req.motivo().isBlank()) {
            m.setObservaciones(req.motivo().trim());
        }
        mantenimientoRepository.save(m);
        if (estabaEnEjecucion) {
            restaurarEstadoActivo(m, "Mantenimiento #" + m.getId() + " cancelado: retorna al estado previo");
        }
        return respuesta(m);
    }

    private void restaurarEstadoActivo(Mantenimiento m, String motivo) {
        Activo activo = m.getActivo();
        if (activo.getEstado() == EstadoActivo.EN_MANTENIMIENTO) {
            EstadoActivo previo = m.getEstadoPrevioActivo() != null ? m.getEstadoPrevioActivo() : EstadoActivo.DISPONIBLE;
            estadoActivoService.aplicarInterno(activo, previo, motivo, sesionService.usuarioActual());
        }
    }

    @Transactional(readOnly = true)
    public List<MantenimientoResponse> listar(Long activoId, EstadoMantenimiento estado) {
        return mantenimientoRepository.findAllByOrderByFechaProgramadaDescIdDesc().stream()
                .filter(m -> activoId == null || m.getActivo().getId().equals(activoId))
                .filter(m -> estado == null || m.getEstado() == estado)
                .map(this::respuesta)
                .toList();
    }

    @Transactional(readOnly = true)
    public MantenimientoActivoResponse porActivo(Long activoId) {
        Activo activo = activo(activoId);
        List<Mantenimiento> lista = mantenimientoRepository.findByActivoOrderByFechaProgramadaDescIdDesc(activo);
        BigDecimal total = BigDecimal.ZERO.setScale(2);
        for (Mantenimiento m : lista) {
            if (m.getEstado() == EstadoMantenimiento.FINALIZADO && m.getCosto() != null) {
                total = total.add(m.getCosto());
            }
        }
        return new MantenimientoActivoResponse(lista.stream().map(this::respuesta).toList(), total);
    }

    @Transactional(readOnly = true)
    public AlertasMantenimientoResponse alertas() {
        LocalDate hoy = LocalDate.now();
        List<MantenimientoResponse> proximos = mantenimientoRepository
                .findByEstadoAndFechaProgramadaBetweenOrderByFechaProgramadaAsc(EstadoMantenimiento.PROGRAMADO, hoy, hoy.plusDays(DIAS_ALERTA))
                .stream().map(this::respuesta).toList();
        List<MantenimientoResponse> vencidos = mantenimientoRepository
                .findByEstadoAndFechaProgramadaLessThanOrderByFechaProgramadaAsc(EstadoMantenimiento.PROGRAMADO, hoy)
                .stream().map(this::respuesta).toList();
        return new AlertasMantenimientoResponse(proximos, vencidos);
    }

    private Mantenimiento obtener(Long id) {
        return mantenimientoRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Mantenimiento no encontrado"));
    }

    private Activo activo(Long id) {
        return activoRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
    }

    private MantenimientoResponse respuesta(Mantenimiento m) {
        Long dias = null;
        if (m.getEstado() == EstadoMantenimiento.PROGRAMADO && m.getFechaProgramada() != null) {
            dias = ChronoUnit.DAYS.between(LocalDate.now(), m.getFechaProgramada());
        }
        return new MantenimientoResponse(
                m.getId(),
                m.getActivo().getId(),
                m.getActivo().getCodigo(),
                m.getActivo().getNombre(),
                m.getTipo().name(),
                m.getEstado().name(),
                m.getDescripcion(),
                m.getFechaProgramada(),
                m.getPeriodicidadDias(),
                m.getFechaInicio(),
                m.getFechaRealizada(),
                m.getCosto(),
                m.getTecnico(),
                m.getObservaciones(),
                dias);
    }
}
