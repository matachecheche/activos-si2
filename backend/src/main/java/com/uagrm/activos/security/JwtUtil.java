package com.uagrm.activos.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.Date;
import java.util.List;

@Component
public class JwtUtil {

    @Value("${app.jwt.secret}")
    private String secret;

    @Value("${app.jwt.expiration-ms}")
    private long expirationMs;

    private SecretKey key() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generarToken(String correo, String rol) {
        return generarToken(correo, rol, List.of());
    }

    /** HU-04: el token lleva el rol y los permisos (formato MODULO_ACCION) del usuario. */
    public String generarToken(String correo, String rol, Collection<String> permisos) {
        Date ahora = new Date();
        Date expira = new Date(ahora.getTime() + expirationMs);
        return Jwts.builder()
                .subject(correo)
                .claim("rol", rol)
                .claim("permisos", List.copyOf(permisos))
                .issuedAt(ahora)
                .expiration(expira)
                .signWith(key(), SignatureAlgorithm.HS256)
                .compact();
    }


    /** Sprint 3 HU-12: token con empresa y nivel (SUPER_ADMIN/ADMIN/REGULAR). */
    public String generarToken(String correo, String rol, Collection<String> permisos,
                               Long empresaId, String nivel) {
        return generarToken(correo, rol, permisos, empresaId, nivel, null);
    }

    /**
     * Sprint 3 / multiempresa: token con empresa, nivel y la membresia
     * (usuario_id) con la que se abrio la sesion. Al cambiar de empresa se
     * emite otro token con la membresia correspondiente.
     */
    public String generarToken(String correo, String rol, Collection<String> permisos,
                               Long empresaId, String nivel, Long usuarioId) {
        Date ahora = new Date();
        Date expira = new Date(ahora.getTime() + expirationMs);
        var builder = Jwts.builder()
                .subject(correo)
                .claim("rol", rol)
                .claim("permisos", List.copyOf(permisos))
                .claim("nivel", nivel == null ? "REGULAR" : nivel);
        if (empresaId != null) {
            builder.claim("empresaId", empresaId);
        }
        if (usuarioId != null) {
            builder.claim("usuarioId", usuarioId);
        }
        return builder.issuedAt(ahora)
                .expiration(expira)
                .signWith(key(), SignatureAlgorithm.HS256)
                .compact();
    }

    /** Membresia (usuario_id) con la que se emitio el token. */
    public Long extraerUsuarioId(String token) {
        Object valor = extraerClaims(token).get("usuarioId");
        return valor == null ? null : Long.valueOf(valor.toString());
    }

    public Long extraerEmpresaId(String token) {
        Object valor = extraerClaims(token).get("empresaId");
        return valor == null ? null : Long.valueOf(valor.toString());
    }

    public String extraerNivel(String token) {
        String nivel = extraerClaims(token).get("nivel", String.class);
        return nivel == null ? "REGULAR" : nivel;
    }

    public Claims extraerClaims(String token) {
        return Jwts.parser().verifyWith(key()).build()
                .parseSignedClaims(token).getPayload();
    }

    public String extraerCorreo(String token) {
        return extraerClaims(token).getSubject();
    }

    public boolean esValido(String token) {
        try {
            Jwts.parser().verifyWith(key()).build().parseSignedClaims(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
