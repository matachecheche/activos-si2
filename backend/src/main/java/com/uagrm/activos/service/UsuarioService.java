package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.dto.UsuarioRequest;
import com.uagrm.activos.dto.UsuarioResponse;
import com.uagrm.activos.model.Cuenta;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.CuentaRepository;
import com.uagrm.activos.repository.RolRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import com.uagrm.activos.saas.PlanLimitsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class UsuarioService {
    private static final String PASSWORD_POLICY = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z\\d]).{8,}$";
    private final UsuarioRepository usuarioRepository;
    private final RolRepository rolRepository;
    private final PasswordEncoder passwordEncoder;
    private final CuentaRepository cuentaRepository;

    @Autowired
    private PlanLimitsService planLimitsService;

    public UsuarioService(UsuarioRepository usuarioRepository, RolRepository rolRepository,
                          PasswordEncoder passwordEncoder, CuentaRepository cuentaRepository) {
        this.usuarioRepository = usuarioRepository;
        this.rolRepository = rolRepository;
        this.passwordEncoder = passwordEncoder;
        this.cuentaRepository = cuentaRepository;
    }

    @Transactional(readOnly = true)
    public List<UsuarioResponse> listar() {
        return usuarioRepository.findAll().stream().map(this::toResponse).toList();
    }

    /** Usuarios activos: candidatos a responsable de un activo (HU-03). */
    @Transactional(readOnly = true)
    public List<UsuarioResponse> listarActivos() {
        return usuarioRepository.findAll().stream()
                .filter(u -> Boolean.TRUE.equals(u.getActivo()))
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "USUARIO", detalleExpresion = "#a0.correo()")
    public UsuarioResponse crear(UsuarioRequest request) {
        planLimitsService.verificarLimiteUsuarios(); // HU-11: limite del plan
        String correo = request.correo().trim().toLowerCase();
        if (!usuarioRepository.findByCorreo(correo).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe un usuario con ese correo en esta empresa");
        }
        if (request.password() == null || !request.password().matches(PASSWORD_POLICY)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La contraseña debe tener mínimo 8 caracteres, mayúscula, minúscula, número y carácter especial");
        }
        // Sprint 3 / multiempresa: la cuenta es global. Si la persona ya
        // existe en otra empresa se reutiliza su cuenta (mismo login) y solo
        // se crea la membresia en esta empresa.
        Cuenta cuenta = cuentaRepository.findByCorreo(correo).orElse(null);
        if (cuenta == null) {
            cuenta = cuentaRepository.save(Cuenta.builder()
                    .correo(correo)
                    .nombre(request.nombre().trim())
                    .password(passwordEncoder.encode(request.password()))
                    .nivel("REGULAR")
                    .intentosFallidos(0)
                    .activo(true)
                    .build());
        } else if (!passwordEncoder.matches(request.password(), cuenta.getPassword())) {
            // La misma persona entra a otra empresa: se unifica la contrasena.
            cuenta.setPassword(passwordEncoder.encode(request.password()));
            cuenta.setIntentosFallidos(0);
            cuenta.setBloqueadoHasta(null);
            cuenta.setActivo(true);
            cuentaRepository.save(cuenta);
        }
        Usuario usuario = Usuario.builder()
                .cuentaId(cuenta.getId())
                .nombre(request.nombre().trim())
                .correo(correo)
                .password(cuenta.getPassword())
                .rol(buscarRolActivo(request.rol()))
                .nivel(cuenta.getNivel())
                .build();
        return toResponse(usuarioRepository.save(usuario));
    }

    @Transactional
    @Auditable(accion = "EDITAR", entidad = "USUARIO", idExpresion = "#a0")
    public UsuarioResponse actualizar(Long id, UsuarioRequest request) {
        Usuario usuario = obtener(id);
        String correo = request.correo().trim().toLowerCase();
        usuarioRepository.findByCorreo(correo).stream()
                .filter(otro -> !otro.getId().equals(id)).findFirst().ifPresent(otro -> { throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe otro usuario con ese correo en esta empresa"); });

        Rol nuevoRol = usuario.getRol().getNombre().equalsIgnoreCase(request.rol())
                ? usuario.getRol() : buscarRolActivo(request.rol());
        boolean quedaraActivo = request.activo() == null ? Boolean.TRUE.equals(usuario.getActivo()) : request.activo();
        boolean eraAdminActivo = esAdministrador(usuario) && Boolean.TRUE.equals(usuario.getActivo());
        boolean seraAdminActivo = RolService.ADMINISTRADOR.equalsIgnoreCase(nuevoRol.getNombre()) && quedaraActivo;
        if (eraAdminActivo && !seraAdminActivo && administradoresActivos() <= 1) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se puede dejar el sistema sin un administrador activo");
        }

        usuario.setNombre(request.nombre().trim());
        usuario.setCorreo(correo);
        usuario.setRol(nuevoRol);
        usuario.setActivo(quedaraActivo);
        if (quedaraActivo) {
            usuario.setIntentosFallidos(0);
            usuario.setBloqueadoHasta(null);
        }
        if (request.password() != null && !request.password().isBlank()) {
            if (!request.password().matches(PASSWORD_POLICY)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La nueva contraseña no cumple la política de seguridad");
            }
            String nuevoHash = passwordEncoder.encode(request.password());
            usuario.setPassword(nuevoHash);
            // La cuenta global es la que manda en el inicio de sesion.
            if (usuario.getCuentaId() != null) {
                cuentaRepository.findById(usuario.getCuentaId()).ifPresent(cuenta -> {
                    cuenta.setPassword(nuevoHash);
                    cuenta.setIntentosFallidos(0);
                    cuenta.setBloqueadoHasta(null);
                    cuentaRepository.save(cuenta);
                });
            }
        }
        return toResponse(usuarioRepository.save(usuario));
    }

    @Transactional
    @Auditable(accion = "ELIMINAR", entidad = "USUARIO", idExpresion = "#a0")
    public void eliminar(Long id) {
        Usuario usuario = obtener(id);
        // HU-04: siempre debe existir al menos un usuario activo con el rol Administrador
        if (esAdministrador(usuario) && Boolean.TRUE.equals(usuario.getActivo()) && administradoresActivos() <= 1) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se puede dejar el sistema sin un administrador activo");
        }
        usuario.setActivo(false);
        usuarioRepository.save(usuario);
    }

    private long administradoresActivos() {
        return usuarioRepository.findAll().stream()
                .filter(otro -> Boolean.TRUE.equals(otro.getActivo()))
                .filter(this::esAdministrador)
                .count();
    }

    private boolean esAdministrador(Usuario usuario) {
        return RolService.ADMINISTRADOR.equalsIgnoreCase(usuario.getRol().getNombre());
    }

    private Usuario obtener(Long id) {
        return usuarioRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
    }

    private Rol buscarRolActivo(String nombre) {
        Rol rol = rolRepository.findByNombre(nombre == null ? "" : nombre.trim().toUpperCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "El rol no existe: " + nombre));
        if (!rol.estaActivo()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El rol " + rol.getNombre() + " está inactivo");
        }
        return rol;
    }

    private UsuarioResponse toResponse(Usuario usuario) {
        return new UsuarioResponse(usuario.getId(), usuario.getNombre(), usuario.getCorreo(), usuario.getRol().getNombre(), usuario.getActivo());
    }
}
