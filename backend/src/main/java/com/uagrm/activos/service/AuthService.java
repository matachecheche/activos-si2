package com.uagrm.activos.service;

import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.security.JwtUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;

// HU-01: Iniciar sesion en el sistema
@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final PermisoRepository permisoRepository;

    @Value("${app.jwt.max-intentos-fallidos}")
    private int maxIntentos;

    @Value("${app.jwt.segundos-bloqueo}")
    private int segundosBloqueo;

    public AuthService(UsuarioRepository usuarioRepository, PasswordEncoder passwordEncoder, JwtUtil jwtUtil, PermisoRepository permisoRepository) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.permisoRepository = permisoRepository;
    }

    public LoginResponse login(LoginRequest request) {
        Usuario usuario = usuarioRepository.findByCorreo(request.getCorreo())
                .orElseThrow(() -> new BadCredentialsException("Credenciales invalidas"));

        if (!Boolean.TRUE.equals(usuario.getActivo())) {
            throw new BadCredentialsException("La cuenta no esta activa");
        }

        if (usuario.getBloqueadoHasta() != null && usuario.getBloqueadoHasta().isAfter(LocalDateTime.now())) {
            long segundosRestantes = Math.max(1, java.time.Duration.between(LocalDateTime.now(), usuario.getBloqueadoHasta()).getSeconds());
            throw new ResponseStatusException(HttpStatus.LOCKED, "Cuenta bloqueada. Intenta nuevamente en " + segundosRestantes + " segundos.");
        }

        if (usuario.getBloqueadoHasta() != null) {
            usuario.setBloqueadoHasta(null);
            usuario.setIntentosFallidos(0);
        }

        if (!passwordEncoder.matches(request.getPassword(), usuario.getPassword())) {
            usuario.setIntentosFallidos(usuario.getIntentosFallidos() + 1);
            if (usuario.getIntentosFallidos() >= maxIntentos) {
                usuario.setBloqueadoHasta(LocalDateTime.now().plusSeconds(segundosBloqueo));
                usuarioRepository.save(usuario);
                throw new ResponseStatusException(HttpStatus.LOCKED, "Cuenta bloqueada durante " + segundosBloqueo + " segundos por superar el limite de intentos.");
            }
            usuarioRepository.save(usuario);
            throw new BadCredentialsException("Credenciales invalidas");
        }

        usuario.setIntentosFallidos(0);
        usuario.setBloqueadoHasta(null);
        usuarioRepository.save(usuario);

        String token = jwtUtil.generarToken(usuario.getCorreo(), usuario.getRol().getNombre());

        return LoginResponse.builder()
                .token(token)
                .nombre(usuario.getNombre())
                .rol(usuario.getRol().getNombre())
                .permisos("ADMINISTRADOR".equalsIgnoreCase(usuario.getRol().getNombre())
                    ? permisoRepository.findAll().stream().map(p -> p.getModulo() + "_" + p.getAccion()).toList()
                    : usuario.getRol().getPermisos().stream().map(p -> p.getModulo() + "_" + p.getAccion()).toList())
                .build();
    }
}
