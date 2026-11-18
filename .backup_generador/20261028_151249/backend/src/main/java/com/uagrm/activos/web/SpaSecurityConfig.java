package com.uagrm.activos.web;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Agregado por desplegar_azure.py.
 * Permite el acceso publico a los archivos estaticos y a las rutas del
 * frontend Angular. La API sigue protegida por el SecurityConfig original
 * (cadena de seguridad por defecto, con JWT), porque todas sus rutas
 * empiezan con /api/** y quedan excluidas de esta cadena.
 */
@Configuration
public class SpaSecurityConfig {

    @Bean
    @Order(0)
    public SecurityFilterChain spaFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher(
                "/",
                "/index.html",
                "/favicon.ico",
                "/robots.txt",
                "/manifest.webmanifest",
                "/manifest.json",
                "/*.js", "/*.css", "/*.ico", "/*.png", "/*.jpg", "/*.jpeg",
                "/*.gif", "/*.svg", "/*.webp", "/*.woff", "/*.woff2",
                "/*.ttf", "/*.eot", "/*.map",
                "/assets/**",
                "/media/**",
                "/icons/**",
                "/{seg:(?!api)[a-zA-Z0-9-]+}",
                "/{seg:(?!api)[a-zA-Z0-9-]+}/**"
            )
            .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
            .csrf(csrf -> csrf.disable());
        return http.build();
    }
}
