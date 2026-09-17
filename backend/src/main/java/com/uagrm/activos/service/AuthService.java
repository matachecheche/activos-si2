package com.uagrm.activos.service;

import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.security.JwtUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

// HU-01: Iniciar sesion en el sistema
@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    @Value("${app.jwt.max-intentos-fallidos}")
    private int maxIntentos;

    @Value("${app.jwt.minutos-bloqueo}")
    private int minutosBloqueo;

    public AuthService(UsuarioRepository usuarioRepository, PasswordEncoder passwordEncoder, JwtUtil jwtUtil) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
    }

    public LoginResponse login(LoginRequest request) {
        Usuario usuario = usuarioRepository.findByCorreo(request.getCorreo())
                .orElseThrow(() -> new BadCredentialsException("Credenciales invalidas"));

        if (usuario.getBloqueadoHasta() != null && usuario.getBloqueadoHasta().isAfter(LocalDateTime.now())) {
            throw new LockedException("Cuenta bloqueada temporalmente. Intente mas tarde.");
        }

        if (!passwordEncoder.matches(request.getPassword(), usuario.getPassword())) {
            usuario.setIntentosFallidos(usuario.getIntentosFallidos() + 1);
            if (usuario.getIntentosFallidos() >= maxIntentos) {
                usuario.setBloqueadoHasta(LocalDateTime.now().plusMinutes(minutosBloqueo));
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
                .build();
    }
}
