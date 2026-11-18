package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.dto.AreaRequest;
import com.uagrm.activos.dto.AreaResponse;
import com.uagrm.activos.dto.UbicacionRequest;
import com.uagrm.activos.dto.UbicacionResponse;
import com.uagrm.activos.model.Area;
import com.uagrm.activos.model.Ubicacion;
import com.uagrm.activos.repository.AreaRepository;
import com.uagrm.activos.repository.UbicacionRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/** Areas (duenas de presupuestos) y ubicaciones fisicas asociadas a un area. */
@Service
public class AreaService {

    private final AreaRepository areaRepository;
    private final UbicacionRepository ubicacionRepository;

    public AreaService(AreaRepository areaRepository, UbicacionRepository ubicacionRepository) {
        this.areaRepository = areaRepository;
        this.ubicacionRepository = ubicacionRepository;
    }

    @Transactional(readOnly = true)
    public List<AreaResponse> listarAreas() {
        return areaRepository.findAll().stream()
                .sorted((a, b) -> a.getNombre().compareToIgnoreCase(b.getNombre()))
                .map(Mapeos::area)
                .toList();
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "AREA")
    public AreaResponse crearArea(AreaRequest req) {
        String nombre = req.nombre().trim();
        if (areaRepository.existsByNombreIgnoreCase(nombre)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe un área con ese nombre");
        }
        Area area = Area.builder()
                .nombre(nombre)
                .descripcion(req.descripcion() == null || req.descripcion().isBlank() ? null : req.descripcion().trim())
                .activo(req.activo() == null || req.activo())
                .build();
        return Mapeos.area(areaRepository.save(area));
    }

    @Transactional
    @Auditable(accion = "EDITAR", entidad = "AREA", idExpresion = "#a0")
    public AreaResponse actualizarArea(Long id, AreaRequest req) {
        Area area = areaRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Área no encontrada"));
        String nombre = req.nombre().trim();
        areaRepository.findByNombreIgnoreCase(nombre).filter(otra -> !otra.getId().equals(id)).ifPresent(otra -> {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe otra área con ese nombre");
        });
        area.setNombre(nombre);
        area.setDescripcion(req.descripcion() == null || req.descripcion().isBlank() ? null : req.descripcion().trim());
        if (req.activo() != null) {
            area.setActivo(req.activo());
        }
        return Mapeos.area(areaRepository.save(area));
    }

    @Transactional(readOnly = true)
    public List<UbicacionResponse> listarUbicaciones() {
        return ubicacionRepository.findAll().stream()
                .sorted((a, b) -> a.getNombre().compareToIgnoreCase(b.getNombre()))
                .map(this::ubicacion)
                .toList();
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "UBICACION")
    public UbicacionResponse crearUbicacion(UbicacionRequest req) {
        Area area = null;
        if (req.areaId() != null) {
            area = areaRepository.findById(req.areaId())
                    .orElseThrow(() -> new IllegalArgumentException("Área no encontrada"));
        }
        Ubicacion ubicacion = Ubicacion.builder().nombre(req.nombre().trim()).area(area).build();
        return ubicacion(ubicacionRepository.save(ubicacion));
    }

    private UbicacionResponse ubicacion(Ubicacion u) {
        return new UbicacionResponse(u.getId(), u.getNombre(),
                u.getArea() == null ? null : u.getArea().getId(),
                u.getArea() == null ? null : u.getArea().getNombre());
    }
}
