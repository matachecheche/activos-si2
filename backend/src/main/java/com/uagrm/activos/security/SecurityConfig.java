package com.uagrm.activos.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.ArrayList;
import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    // Origenes permitidos para desarrollo local. En produccion se amplian con
    // APP_CORS_ORIGINS (lista separada por comas) o APP_CORS_ORIGIN (uno solo).
    private static final List<String> ORIGENES_LOCAL = List.of(
            "http://localhost:4200",
            "http://127.0.0.1:4200");

    @Value("${APP_CORS_ORIGIN:https://activos-si2-1.onrender.com}")
    private String corsOrigin;

    @Value("${APP_CORS_ORIGINS:}")
    private String corsOriginsExtra;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        // HU-12: costo 12 exigido por la politica de contrasenas
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .headers(headers -> headers
                // CSP pensada para la SPA de Angular servida desde este mismo
                // backend: los estilos de los componentes se inyectan en linea
                // ('unsafe-inline') y las imagenes de la app (logo de la
                // empresa, codigo QR de pago) llegan como data:/blob:.
                .contentSecurityPolicy(csp -> csp.policyDirectives(
                        "default-src 'self'; "
                        + "script-src 'self'; "
                        + "style-src 'self' 'unsafe-inline'; "
                        + "img-src 'self' data: blob:; "
                        + "font-src 'self' data:; "
                        + "connect-src 'self' http://localhost:4200 http://127.0.0.1:4200; "
                        + "frame-ancestors 'none'; object-src 'none'; base-uri 'self'"))
                .frameOptions(frame -> frame.deny())
                .httpStrictTransportSecurity(hsts -> hsts.includeSubDomains(true).maxAgeInSeconds(31536000)))
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(ex -> ex.authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
            .authorizeHttpRequests(auth -> auth
                // Solo el login y el registro publico son abiertos. El resto
                // de /api/auth (mis-empresas, cambiar-empresa) exige token.
                .requestMatchers("/api/auth/login", "/api/auth/registro",
                                 "/api/auth/registro-empresa").permitAll()
                .requestMatchers("/api/public/**").permitAll()
                // El webhook lo llama la pasarela de pagos: no tiene cuenta del
                // sistema. La seguridad la da la verificacion server to server
                // contra la API del proveedor (estado real del pago).
                .requestMatchers("/api/pagos/webhook/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        List<String> origenes = new ArrayList<>(ORIGENES_LOCAL);
        // Origenes configurables por variable de entorno (despliegues distintos).
        if (corsOriginsExtra != null && !corsOriginsExtra.isBlank()) {
            for (String o : corsOriginsExtra.split(",")) {
                if (!o.isBlank() && !origenes.contains(o.trim())) {
                    origenes.add(o.trim());
                }
            }
        }
        if (corsOrigin != null && !corsOrigin.isBlank() && !origenes.contains(corsOrigin.trim())) {
            origenes.add(corsOrigin.trim());
        }
        config.setAllowedOrigins(origenes);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
