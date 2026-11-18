package com.uagrm.activos.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.util.StreamUtils;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Aplica las migraciones SQL de recursos (db/*.sql) al arrancar. Es idempotente
 * (los scripts usan IF NOT EXISTS / DO $$ guards) y entiende bloques
 * dollar-quoted ($$ ... $$ o $tag$ ... $tag$), por lo que funciones y
 * disparadores se ejecutan como una sola sentencia.
 */
@Component
@Order(0)
public class MigrationInitializer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(MigrationInitializer.class);
    private static final String[] SCRIPTS = {"db/V3__sprint3.sql", "db/V4__multiempresa_pagos.sql",
            "db/V5__permisos_admin.sql"};
    private static final Pattern DOLAR = Pattern.compile("\\$[A-Za-z0-9_]*\\$");

    private final JdbcTemplate jdbcTemplate;

    public MigrationInitializer(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(String... args) {
        for (String recurso : SCRIPTS) {
            try {
                String sql = StreamUtils.copyToString(
                        new ClassPathResource(recurso).getInputStream(), StandardCharsets.UTF_8);
                int ejecutadas = 0;
                for (String sentencia : dividir(sql)) {
                    if (!sentencia.isBlank()) {
                        jdbcTemplate.execute(sentencia);
                        ejecutadas++;
                    }
                }
                log.info("Migracion {} aplicada ({} sentencias)", recurso, ejecutadas);
            } catch (Exception e) {
                log.error("Fallo la migracion {}: {}", recurso, e.getMessage());
                throw new IllegalStateException("No se pudo aplicar " + recurso, e);
            }
        }
    }

    /** Divide en ';' respetando comillas simples y bloques dollar-quoted. */
    static List<String> dividir(String sql) {
        List<String> sentencias = new ArrayList<>();
        StringBuilder actual = new StringBuilder();
        String tagDolar = null;
        boolean comillaSimple = false;
        boolean lineaComentario = false;
        for (int i = 0; i < sql.length(); i++) {
            char c = sql.charAt(i);
            char next = i + 1 < sql.length() ? sql.charAt(i + 1) : '\0';

            if (lineaComentario) {
                actual.append(c);
                if (c == '\n') {
                    lineaComentario = false;
                }
                continue;
            }
            if (!comillaSimple && tagDolar == null && c == '-' && next == '-') {
                lineaComentario = true;
                actual.append(c);
                continue;
            }
            if (c == '\'' && tagDolar == null) {
                comillaSimple = !comillaSimple;
                actual.append(c);
                continue;
            }
            if (!comillaSimple) {
                Matcher m = DOLAR.matcher(sql.substring(i));
                if (m.find() && m.start() == 0) {
                    String token = m.group();
                    actual.append(token);
                    i += token.length() - 1;
                    if (tagDolar == null) {
                        tagDolar = token;
                    } else if (tagDolar.equals(token)) {
                        tagDolar = null;
                    }
                    continue;
                }
            }
            if (c == ';' && !comillaSimple && tagDolar == null) {
                sentencias.add(actual.toString().trim());
                actual.setLength(0);
                continue;
            }
            actual.append(c);
        }
        if (!actual.toString().isBlank()) {
            sentencias.add(actual.toString().trim());
        }
        return sentencias;
    }
}
