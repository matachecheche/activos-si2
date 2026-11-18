package com.uagrm.activos.security;

import com.uagrm.activos.tenant.TenantContext;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

/**
 * Valida el JWT de cada peticion, reconstruye la identidad y rellena el
 * TenantContext (HU-11/HU-12). El TenantHibernateFilter, que va despues,
 * activa el aislamiento por empresa usando este contexto.
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;

    public JwtAuthFilter(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain chain)
            throws ServletException, IOException {
        String encabezado = request.getHeader(HttpHeaders.AUTHORIZATION);
        // Toda peticion empieza con contexto limpio: los hilos de Tomcat se reciclan
        // y un TenantContext residual filtraria las consultas con el tenant anterior.
        TenantContext.limpiar();
        try {
        if (encabezado != null && encabezado.startsWith("Bearer ")) {
            try {
                String token = encabezado.substring(7);
                Claims claims = jwtUtil.extraerClaims(token);
                String correo = claims.getSubject();
                String rol = claims.get("rol", String.class);
                String nivel = claims.get("nivel", String.class);
                if (nivel == null) {
                    nivel = "REGULAR";
                }
                Object empresaClaim = claims.get("empresaId");
                Long empresaId = empresaClaim == null ? null : Long.valueOf(empresaClaim.toString());

                Collection<SimpleGrantedAuthority> autoridades = extraerPermisos(claims, rol, nivel);
                UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(correo, null, autoridades);
                SecurityContextHolder.getContext().setAuthentication(auth);

                Object usuarioClaim = claims.get("usuarioId");
                Long usuarioId = usuarioClaim == null ? null : Long.valueOf(usuarioClaim.toString());

                TenantContext.setCorreo(correo);
                TenantContext.setNivel(nivel);
                TenantContext.setEmpresaId(empresaId);
                // La membresia (usuario_id) queda en el contexto para la
                // bitacora, el inventario y los respaldos.
                TenantContext.setUsuarioId(usuarioId);
                TenantContext.setIp(ipDelCliente(request));
                TenantContext.setEquipo(request.getHeader("User-Agent"));
            } catch (Exception e) {
                SecurityContextHolder.clearContext();
                TenantContext.limpiar();
            }
        }
            chain.doFilter(request, response);
        } finally {
            // Imprescindible: nunca dejar identidad en un hilo reciclado.
            TenantContext.limpiar();
            SecurityContextHolder.clearContext();
        }
    }

    @SuppressWarnings("unchecked")
    private Collection<SimpleGrantedAuthority> extraerPermisos(Claims claims, String rol, String nivel) {
        List<SimpleGrantedAuthority> autoridades = new java.util.ArrayList<>();
        Object crudo = claims.get("permisos");
        if (crudo instanceof List<?> lista) {
            lista.stream().map(String::valueOf).map(p -> new SimpleGrantedAuthority("PERM_" + p))
                    .forEach(autoridades::add);
        }
        // El rol del usuario SIEMPRE genera su autoridad ROLE_<rol>, incluso
        // cuando el token tambien trae la lista de permisos explicitos. Los
        // endpoints administrados usan hasRole('ADMINISTRADOR'); sin esta linea
        // el administrador solo recibia PERM_* y ROLE_REGULAR (su nivel) y el
        // backend respondia 403 en roles, permisos y demas pantallas de admin.
        if (rol != null && !rol.isBlank()) {
            autoridades.add(new SimpleGrantedAuthority("ROLE_" + rol));
        }
        // HU-12: autoridad por nivel (ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_REGULAR)
        if (nivel != null) {
            autoridades.add(new SimpleGrantedAuthority("ROLE_" + nivel));
        }
        return autoridades;
    }

    /** Detras de Azure App Service la IP real viaja en X-Forwarded-For. */
    private String ipDelCliente(HttpServletRequest request) {
        String reenviada = request.getHeader("X-Forwarded-For");
        if (reenviada != null && !reenviada.isBlank()) {
            return reenviada.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
