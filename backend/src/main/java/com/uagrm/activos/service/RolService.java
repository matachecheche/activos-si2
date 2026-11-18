package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.dto.PermisoRequest;
import com.uagrm.activos.dto.PermisoResponse;
import com.uagrm.activos.dto.RolOpcionResponse;
import com.uagrm.activos.dto.RolRequest;
import com.uagrm.activos.dto.RolResponse;
import com.uagrm.activos.model.Permiso;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.repository.RolRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** HU-04: roles y permisos por modulo y accion. */
@Service
public class RolService {

    public static final String ADMINISTRADOR = "ADMINISTRADOR";

    private final RolRepository rolRepository;
    private final PermisoRepository permisoRepository;
    private final UsuarioRepository usuarioRepository;

    public RolService(RolRepository rolRepository, PermisoRepository permisoRepository, UsuarioRepository usuarioRepository) {
        this.rolRepository = rolRepository;
        this.permisoRepository = permisoRepository;
        this.usuarioRepository = usuarioRepository;
    }

    @Transactional(readOnly = true)
    public List<RolResponse> listar() {
        return rolRepository.findAll().stream()
                .sorted((a, b) -> a.getNombre().compareToIgnoreCase(b.getNombre()))
                .map(this::respuesta)
                .toList();
    }

    /** Roles activos que se pueden asignar a un usuario. */
    @Transactional(readOnly = true)
    public List<RolOpcionResponse> disponibles() {
        return rolRepository.findAll().stream()
                .filter(Rol::estaActivo)
                .sorted((a, b) -> a.getNombre().compareToIgnoreCase(b.getNombre()))
                .map(r -> new RolOpcionResponse(r.getId(), r.getNombre(), r.getDescripcion()))
                .toList();
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "ROL")
    public RolResponse crear(RolRequest req) {
        String nombre = req.nombre().trim().toUpperCase();
        if (rolRepository.existsByNombreIgnoreCase(nombre)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe un rol con ese nombre");
        }
        Rol rol = new Rol();
        rol.setNombre(nombre);
        rol.setDescripcion(descripcion(req.descripcion()));
        rol.setActivo(true);
        rol.setPermisos(buscarPermisos(req.permisos()));
        return respuesta(rolRepository.save(rol));
    }

    @Transactional
    @Auditable(accion = "EDITAR", entidad = "ROL", idExpresion = "#a0")
    public RolResponse actualizar(Long id, RolRequest req) {
        Rol rol = obtener(id);
        String nombre = req.nombre().trim().toUpperCase();
        boolean esAdmin = ADMINISTRADOR.equalsIgnoreCase(rol.getNombre());
        if (esAdmin && !ADMINISTRADOR.equals(nombre)) {
            throw new IllegalStateException("El rol ADMINISTRADOR no puede renombrarse");
        }
        rolRepository.findByNombre(nombre).filter(otro -> !otro.getId().equals(id)).ifPresent(otro -> {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe otro rol con ese nombre");
        });
        if (req.activo() != null && !req.activo()) {
            validarDesactivacion(rol);
        }
        rol.setNombre(nombre);
        rol.setDescripcion(descripcion(req.descripcion()));
        if (req.activo() != null) {
            rol.setActivo(req.activo());
        }
        if (!esAdmin) {
            rol.setPermisos(buscarPermisos(req.permisos()));
        }
        return respuesta(rolRepository.save(rol));
    }

    /** CP-02: un rol con usuarios activos asignados no puede desactivarse. */
    @Transactional
    @Auditable(accion = "DESACTIVAR", entidad = "ROL", idExpresion = "#a0")
    public RolResponse desactivar(Long id) {
        Rol rol = obtener(id);
        validarDesactivacion(rol);
        rol.setActivo(false);
        return respuesta(rolRepository.save(rol));
    }

    private void validarDesactivacion(Rol rol) {
        if (ADMINISTRADOR.equalsIgnoreCase(rol.getNombre())) {
            throw new IllegalStateException("El rol ADMINISTRADOR no puede desactivarse");
        }
        long activos = usuariosActivos(rol);
        if (activos > 0) {
            throw new IllegalStateException("No se puede desactivar el rol " + rol.getNombre() + ": tiene " + activos
                    + " usuario(s) activo(s) asignado(s)");
        }
    }

    // ---- catalogo de permisos ----

    @Transactional(readOnly = true)
    public List<PermisoResponse> listarPermisos() {
        return permisoRepository.findAll().stream()
                .sorted((a, b) -> (a.getModulo() + a.getAccion()).compareTo(b.getModulo() + b.getAccion()))
                .map(this::permisoRespuesta)
                .toList();
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "PERMISO")
    public PermisoResponse crearPermiso(PermisoRequest req) {
        String modulo = req.modulo().trim().toUpperCase();
        String accion = req.accion().trim().toUpperCase();
        if (permisoRepository.findByModuloAndAccion(modulo, accion).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe ese permiso");
        }
        Permiso permiso = Permiso.builder().modulo(modulo).accion(accion).descripcion(req.descripcion().trim()).build();
        return permisoRespuesta(permisoRepository.save(permiso));
    }

    @Transactional
    public PermisoResponse actualizarPermiso(Long id, PermisoRequest req) {
        Permiso permiso = permisoRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Permiso no encontrado"));
        String modulo = req.modulo().trim().toUpperCase();
        String accion = req.accion().trim().toUpperCase();
        permisoRepository.findByModuloAndAccion(modulo, accion).filter(otro -> !otro.getId().equals(id)).ifPresent(otro -> {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe ese permiso");
        });
        permiso.setModulo(modulo);
        permiso.setAccion(accion);
        permiso.setDescripcion(req.descripcion().trim());
        return permisoRespuesta(permisoRepository.save(permiso));
    }

    @Transactional
    @Auditable(accion = "ELIMINAR", entidad = "PERMISO", idExpresion = "#a0")
    public void eliminarPermiso(Long id) {
        if (!permisoRepository.existsById(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Permiso no encontrado");
        }
        for (Rol rol : rolRepository.findAll()) {
            if (rol.getPermisos().removeIf(permiso -> permiso.getId().equals(id))) {
                rolRepository.save(rol);
            }
        }
        permisoRepository.deleteById(id);
    }

    // ---- auxiliares ----

    private Rol obtener(Long id) {
        return rolRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Rol no encontrado"));
    }

    private Set<Permiso> buscarPermisos(Set<Long> ids) {
        Set<Permiso> permisos = new HashSet<>();
        if (ids == null) {
            return permisos;
        }
        for (Long id : ids) {
            permisos.add(permisoRepository.findById(id)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Permiso no encontrado: " + id)));
        }
        return permisos;
    }

    private String descripcion(String texto) {
        return texto == null || texto.isBlank() ? null : texto.trim();
    }

    private long usuariosActivos(Rol rol) {
        return usuarioRepository.findByRol(rol).stream().filter(u -> Boolean.TRUE.equals(u.getActivo())).count();
    }

    private RolResponse respuesta(Rol rol) {
        // el administrador tiene todos los permisos, aunque se creen nuevos en el catalogo
        Set<Permiso> permisos = ADMINISTRADOR.equalsIgnoreCase(rol.getNombre())
                ? new HashSet<>(permisoRepository.findAll()) : rol.getPermisos();
        return new RolResponse(rol.getId(), rol.getNombre(), rol.getDescripcion(), rol.estaActivo(),
                permisos.stream().map(this::permisoRespuesta).collect(Collectors.toSet()), usuariosActivos(rol));
    }

    private PermisoResponse permisoRespuesta(Permiso permiso) {
        return new PermisoResponse(permiso.getId(), permiso.getModulo(), permiso.getAccion(), permiso.getDescripcion());
    }
}
