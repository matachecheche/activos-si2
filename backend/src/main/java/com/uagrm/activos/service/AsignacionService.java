package com.uagrm.activos.service;

import com.uagrm.activos.dto.AsignacionRequest;
import com.uagrm.activos.model.*;
import com.uagrm.activos.repository.*;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

// HU-03: Asignar activos a responsables y ubicaciones
@Service
public class AsignacionService {

    private final AsignacionRepository asignacionRepository;
    private final ActivoRepository activoRepository;
    private final UsuarioRepository usuarioRepository;
    private final UbicacionRepository ubicacionRepository;

    public AsignacionService(AsignacionRepository asignacionRepository,
                              ActivoRepository activoRepository,
                              UsuarioRepository usuarioRepository,
                              UbicacionRepository ubicacionRepository) {
        this.asignacionRepository = asignacionRepository;
        this.activoRepository = activoRepository;
        this.usuarioRepository = usuarioRepository;
        this.ubicacionRepository = ubicacionRepository;
    }

    public List<Asignacion> historial(Long activoId) {
        Activo activo = activoRepository.findById(activoId)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
        return asignacionRepository.findByActivoOrderByFechaAsignacionDesc(activo);
    }

    public Asignacion asignar(AsignacionRequest req) {
        Activo activo = activoRepository.findById(req.getActivoId())
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));

        if (activo.getEstado() == EstadoActivo.BAJA) {
            throw new IllegalStateException("No se puede asignar un activo dado de baja");
        }

        Usuario responsable = usuarioRepository.findById(req.getResponsableId())
                .orElseThrow(() -> new IllegalArgumentException("Responsable no encontrado"));
        Ubicacion ubicacion = ubicacionRepository.findById(req.getUbicacionId())
                .orElseThrow(() -> new IllegalArgumentException("Ubicacion no encontrada"));

        // Solo un responsable activo a la vez: cierra la asignacion previa (conserva historial)
        asignacionRepository.findByActivoAndActivaTrue(activo).ifPresent(anterior -> {
            anterior.setActiva(false);
            asignacionRepository.save(anterior);
        });

        Asignacion nueva = Asignacion.builder()
                .activo(activo)
                .responsable(responsable)
                .ubicacion(ubicacion)
                .fechaAsignacion(LocalDateTime.now())
                .activa(true)
                .build();
        asignacionRepository.save(nueva);

        activo.setResponsable(responsable);
        activo.setUbicacion(ubicacion);
        activo.setEstado(EstadoActivo.EN_USO);
        activoRepository.save(activo);

        return nueva;
    }
}
