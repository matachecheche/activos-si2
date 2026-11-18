package com.uagrm.activos.service;

import com.uagrm.activos.domain.ReglasEstadoActivo;
import com.uagrm.activos.dto.HistorialEstadoResponse;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.model.EstadoMantenimiento;
import com.uagrm.activos.model.HistorialEstadoActivo;
import com.uagrm.activos.model.Mantenimiento;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.AsignacionRepository;
import com.uagrm.activos.repository.HistorialEstadoRepository;
import com.uagrm.activos.repository.MantenimientoRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * HU-06: unico punto por el que cambia el estado de un activo. Valida las transiciones permitidas
 * (Figura 11) y escribe el historial; asignaciones y mantenimientos no modifican el estado directamente.
 */
@Service
public class EstadoActivoService {

    private final ActivoRepository activoRepository;
    private final HistorialEstadoRepository historialRepository;
    private final AsignacionRepository asignacionRepository;
    private final MantenimientoRepository mantenimientoRepository;

    public EstadoActivoService(ActivoRepository activoRepository,
                               HistorialEstadoRepository historialRepository,
                               AsignacionRepository asignacionRepository,
                               MantenimientoRepository mantenimientoRepository) {
        this.activoRepository = activoRepository;
        this.historialRepository = historialRepository;
        this.asignacionRepository = asignacionRepository;
        this.mantenimientoRepository = mantenimientoRepository;
    }

    /** Cambio solicitado por una persona desde la ficha del activo (exige motivo). */
    @Transactional
    public Activo cambiarManual(Activo activo, EstadoActivo nuevo, String motivo, Usuario usuario,
                                boolean esAdministrador, boolean puedeDarDeBaja) {
        EstadoActivo actual = activo.getEstado() == null ? EstadoActivo.DISPONIBLE : activo.getEstado();
        String motivoLimpio = motivo == null ? "" : motivo.trim();
        if (motivoLimpio.isEmpty()) {
            throw new IllegalArgumentException("Debe indicar el motivo del cambio de estado");
        }
        if (nuevo == null) {
            throw new IllegalArgumentException("Debe indicar el nuevo estado");
        }
        if (nuevo == actual) {
            throw new IllegalStateException("El activo ya se encuentra en estado " + actual.getEtiqueta());
        }
        if (actual == EstadoActivo.DADO_DE_BAJA && !esAdministrador) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Solo un administrador puede reactivar un activo dado de baja");
        }
        if (nuevo == EstadoActivo.DADO_DE_BAJA && !puedeDarDeBaja) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No tiene permiso para dar de baja activos");
        }
        if (nuevo == EstadoActivo.EN_USO) {
            throw new IllegalStateException("Para poner un activo En uso debe asignarlo a un responsable desde la sección de asignación");
        }
        if (nuevo == EstadoActivo.EN_MANTENIMIENTO) {
            throw new IllegalStateException("El estado En mantenimiento se establece al iniciar un mantenimiento");
        }
        if (actual == EstadoActivo.EN_MANTENIMIENTO && nuevo != EstadoActivo.DADO_DE_BAJA) {
            throw new IllegalStateException("Finalice o cancele el mantenimiento en ejecución antes de cambiar el estado");
        }
        if (!ReglasEstadoActivo.permitida(actual, nuevo)) {
            throw new IllegalStateException("No se puede pasar de " + actual.getEtiqueta() + " a " + nuevo.getEtiqueta());
        }
        aplicar(activo, actual, nuevo, motivoLimpio, usuario);
        return activo;
    }

    /** Cambio provocado por otro modulo (asignacion o mantenimiento). */
    @Transactional
    public void aplicarInterno(Activo activo, EstadoActivo nuevo, String motivo, Usuario usuario) {
        EstadoActivo actual = activo.getEstado() == null ? EstadoActivo.DISPONIBLE : activo.getEstado();
        if (actual == nuevo) {
            return;
        }
        if (!ReglasEstadoActivo.permitida(actual, nuevo)) {
            throw new IllegalStateException("No se puede pasar de " + actual.getEtiqueta() + " a " + nuevo.getEtiqueta());
        }
        aplicar(activo, actual, nuevo, motivo, usuario);
    }

    private void aplicar(Activo activo, EstadoActivo anterior, EstadoActivo nuevo, String motivo, Usuario usuario) {
        if (nuevo == EstadoActivo.DISPONIBLE || nuevo == EstadoActivo.DADO_DE_BAJA) {
            liberarAsignacion(activo);
        }
        if (nuevo == EstadoActivo.DADO_DE_BAJA) {
            activo.setFechaBaja(LocalDate.now());
            cancelarMantenimientosAbiertos(activo);
        }
        if (anterior == EstadoActivo.DADO_DE_BAJA && nuevo == EstadoActivo.DISPONIBLE) {
            activo.setFechaBaja(null);
        }
        activo.setEstado(nuevo);
        activoRepository.save(activo);
        historialRepository.save(HistorialEstadoActivo.builder()
                .activo(activo)
                .estadoAnterior(anterior)
                .estadoNuevo(nuevo)
                .motivo(recortar(motivo, 255))
                .usuario(usuario)
                .fecha(LocalDateTime.now())
                .build());
    }

    private void liberarAsignacion(Activo activo) {
        asignacionRepository.findByActivoAndActivaTrue(activo).ifPresent(asignacion -> {
            asignacion.setActiva(false);
            asignacionRepository.save(asignacion);
        });
        activo.setResponsable(null);
        activo.setUbicacion(null);
    }

    private void cancelarMantenimientosAbiertos(Activo activo) {
        List<Mantenimiento> abiertos = mantenimientoRepository.findByActivoAndEstadoIn(activo,
                List.of(EstadoMantenimiento.PROGRAMADO, EstadoMantenimiento.EN_EJECUCION));
        for (Mantenimiento m : abiertos) {
            m.setEstado(EstadoMantenimiento.CANCELADO);
            m.setObservaciones(recortar("Cancelado por baja del activo", 500));
            mantenimientoRepository.save(m);
        }
    }

    @Transactional(readOnly = true)
    public List<HistorialEstadoResponse> historial(Activo activo) {
        return historialRepository.findByActivoOrderByFechaDescIdDesc(activo).stream()
                .map(h -> new HistorialEstadoResponse(
                        h.getId(),
                        h.getEstadoAnterior() == null ? null : h.getEstadoAnterior().name(),
                        h.getEstadoAnterior() == null ? null : h.getEstadoAnterior().getEtiqueta(),
                        h.getEstadoNuevo().name(),
                        h.getEstadoNuevo().getEtiqueta(),
                        h.getMotivo(),
                        h.getUsuario() == null ? "Sistema" : h.getUsuario().getNombre(),
                        h.getFecha()))
                .toList();
    }

    private static String recortar(String texto, int max) {
        if (texto == null) {
            return "";
        }
        return texto.length() <= max ? texto : texto.substring(0, max);
    }
}
