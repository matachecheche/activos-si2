package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.dto.AsignacionRequest;
import com.uagrm.activos.dto.AsignacionResponse;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Asignacion;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.model.Ubicacion;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.AsignacionRepository;
import com.uagrm.activos.repository.UbicacionRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

// HU-03: Asignar activos a responsables y ubicaciones (conserva el historial)
@Service
public class AsignacionService {

    private final AsignacionRepository asignacionRepository;
    private final ActivoRepository activoRepository;
    private final UsuarioRepository usuarioRepository;
    private final UbicacionRepository ubicacionRepository;
    private final EstadoActivoService estadoActivoService;
    private final SesionService sesionService;

    public AsignacionService(AsignacionRepository asignacionRepository,
                             ActivoRepository activoRepository,
                             UsuarioRepository usuarioRepository,
                             UbicacionRepository ubicacionRepository,
                             EstadoActivoService estadoActivoService,
                             SesionService sesionService) {
        this.asignacionRepository = asignacionRepository;
        this.activoRepository = activoRepository;
        this.usuarioRepository = usuarioRepository;
        this.ubicacionRepository = ubicacionRepository;
        this.estadoActivoService = estadoActivoService;
        this.sesionService = sesionService;
    }

    @Transactional(readOnly = true)
    public List<AsignacionResponse> historial(Long activoId) {
        Activo activo = activoRepository.findById(activoId)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
        return asignacionRepository.findByActivoOrderByFechaAsignacionDesc(activo).stream()
                .map(this::respuesta)
                .toList();
    }

    @Transactional
    @Auditable(accion = "ASIGNAR", entidad = "ASIGNACION")
    public AsignacionResponse asignar(AsignacionRequest req) {
        Activo activo = activoRepository.findById(req.activoId())
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));

        EstadoActivo estado = activo.getEstado() == null ? EstadoActivo.DISPONIBLE : activo.getEstado();
        if (estado == EstadoActivo.DADO_DE_BAJA) {
            throw new IllegalStateException("No se puede asignar un activo dado de baja");
        }
        if (estado == EstadoActivo.EN_MANTENIMIENTO) {
            throw new IllegalStateException("No se puede asignar un activo que está en mantenimiento");
        }
        if (estado == EstadoActivo.INACTIVO) {
            throw new IllegalStateException("Un activo inactivo debe pasar a Disponible antes de asignarse");
        }

        Usuario responsable = usuarioRepository.findById(req.responsableId())
                .orElseThrow(() -> new IllegalArgumentException("Responsable no encontrado"));
        if (!Boolean.TRUE.equals(responsable.getActivo())) {
            throw new IllegalArgumentException("El responsable seleccionado está inactivo");
        }
        Ubicacion ubicacion = ubicacionRepository.findById(req.ubicacionId())
                .orElseThrow(() -> new IllegalArgumentException("Ubicación no encontrada"));

        // Solo un responsable activo a la vez: cierra la asignacion previa (conserva historial)
        asignacionRepository.findByActivoAndActivaTrue(activo).ifPresent(anterior -> {
            anterior.setActiva(false);
            asignacionRepository.save(anterior);
        });

        Asignacion nueva = asignacionRepository.save(Asignacion.builder()
                .activo(activo)
                .responsable(responsable)
                .ubicacion(ubicacion)
                .fechaAsignacion(LocalDateTime.now())
                .activa(true)
                .build());

        activo.setResponsable(responsable);
        activo.setUbicacion(ubicacion);
        if (estado == EstadoActivo.EN_USO) {
            activoRepository.save(activo);
        } else {
            // HU-06: al asignar, el activo pasa a En uso (queda registrado en el historial de estados)
            estadoActivoService.aplicarInterno(activo, EstadoActivo.EN_USO,
                    "Asignación a " + responsable.getNombre(), sesionService.usuarioActual());
        }
        return respuesta(nueva);
    }

    private AsignacionResponse respuesta(Asignacion a) {
        return new AsignacionResponse(
                a.getId(),
                a.getActivo().getId(),
                a.getActivo().getCodigo(),
                Mapeos.usuarioRef(a.getResponsable()),
                Mapeos.ubicacionRef(a.getUbicacion()),
                a.getFechaAsignacion(),
                a.getActiva());
    }
}
