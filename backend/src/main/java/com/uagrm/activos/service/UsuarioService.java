package com.uagrm.activos.service;

import com.uagrm.activos.dto.UsuarioRequest;
import com.uagrm.activos.dto.UsuarioResponse;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.RolRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class UsuarioService {
    private static final String PASSWORD_POLICY = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z\\d]).{8,}$";
    private final UsuarioRepository usuarioRepository;
    private final RolRepository rolRepository;
    private final PasswordEncoder passwordEncoder;

    public UsuarioService(UsuarioRepository usuarioRepository, RolRepository rolRepository, PasswordEncoder passwordEncoder) {
        this.usuarioRepository = usuarioRepository;
        this.rolRepository = rolRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public List<UsuarioResponse> listar() {
        return usuarioRepository.findAll().stream().map(this::toResponse).toList();
    }

    public UsuarioResponse crear(UsuarioRequest request) {
        if (usuarioRepository.findByCorreo(request.correo()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe un usuario con ese correo");
        }
        if (request.password() == null || !request.password().matches(PASSWORD_POLICY)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La contrasena debe tener minimo 8 caracteres, mayuscula, minuscula, numero y caracter especial");
        }
        Usuario usuario = Usuario.builder()
                .nombre(request.nombre().trim())
                .correo(request.correo().trim().toLowerCase())
                .password(passwordEncoder.encode(request.password()))
                .rol(buscarRol(request.rol()))
                .build();
        return toResponse(usuarioRepository.save(usuario));
    }

    public UsuarioResponse actualizar(Long id, UsuarioRequest request) {
        Usuario usuario = obtener(id);
        usuarioRepository.findByCorreo(request.correo()).filter(otro -> !otro.getId().equals(id))
                .ifPresent(otro -> { throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe otro usuario con ese correo"); });
        usuario.setNombre(request.nombre().trim());
        usuario.setCorreo(request.correo().trim().toLowerCase());
        usuario.setRol(buscarRol(request.rol()));
        if (request.password() != null && !request.password().isBlank()) {
            if (!request.password().matches(PASSWORD_POLICY)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La nueva contrasena no cumple la politica de seguridad");
            }
            usuario.setPassword(passwordEncoder.encode(request.password()));
        }
        return toResponse(usuarioRepository.save(usuario));
    }

    public void eliminar(Long id) {
        Usuario usuario = obtener(id);
        if ("ADMINISTRADOR".equalsIgnoreCase(usuario.getRol().getNombre())
                && usuarioRepository.findAll().stream()
                .filter(otro -> Boolean.TRUE.equals(otro.getActivo()))
                .filter(otro -> "ADMINISTRADOR".equalsIgnoreCase(otro.getRol().getNombre()))
                .count() <= 1) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se puede dejar el sistema sin un administrador activo");
        }
        usuario.setActivo(false);
        usuarioRepository.save(usuario);
    }

    private Usuario obtener(Long id) {
        return usuarioRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
    }

    private Rol buscarRol(String nombre) {
        return rolRepository.findByNombre(nombre).orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "El rol no existe: " + nombre));
    }

    private UsuarioResponse toResponse(Usuario usuario) {
        return new UsuarioResponse(usuario.getId(), usuario.getNombre(), usuario.getCorreo(), usuario.getRol().getNombre(), usuario.getActivo());
    }
}