package com.uagrm.activos;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Prepara una base de datos local de pruebas para la prueba de contexto del
 * backend ({@link ActivosBackendApplicationTests}).
 *
 * <p>Antes, esa prueba fallaba si el equipo no tenia creada a mano la base
 * "activos_fijos_db". Ahora el propio test crea (si hace falta) una base
 * exclusiva de pruebas llamada "activos_fijos_db_prueba", le aplica el
 * schema.sql del proyecto y devuelve la URL para que Spring la use.</p>
 *
 * <p>Si la base configurada NO es local (Neon, un servidor propio...) no se
 * toca nada: se usa tal cual la que venga en SPRING_DATASOURCE_URL.</p>
 */
final class DbDePrueba {

    private static final String NOMBRE_BASE = "activos_fijos_db_prueba";
    private static final Pattern URL_CON_BASE = Pattern.compile("^(.*/)([^/?]+)(\\?.*)?$");

    private DbDePrueba() {
    }

    /** Devuelve la URL de la base de datos que debe usar la prueba de contexto. */
    static String urlDePrueba() {
        String url = valor("SPRING_DATASOURCE_URL", "jdbc:postgresql://localhost:5432/activos_fijos_db");
        String usuario = valor("SPRING_DATASOURCE_USERNAME", "postgres");
        String clave = valor("SPRING_DATASOURCE_PASSWORD", "password1234");

        if (!esLocal(url)) {
            // Base remota (Neon, servidor propio): no se crea ni se toca nada.
            return url;
        }

        String urlAdmin = conBase(url, "postgres");
        String urlPrueba = conBase(url, NOMBRE_BASE);
        try {
            if (!existe(urlPrueba, usuario, clave)) {
                crear(urlAdmin, NOMBRE_BASE, usuario, clave);
            }
            aplicarSchema(urlPrueba, usuario, clave);
        } catch (Exception e) {
            throw new IllegalStateException(
                    "No se pudo preparar la base de pruebas (" + urlPrueba + "). "
                            + "Comprueba que PostgreSQL este instalado y arrancado, "
                            + "o define SPRING_DATASOURCE_URL para usar otra base.",
                    e);
        }
        return urlPrueba;
    }

    private static String valor(String variable, String porDefecto) {
        String v = System.getenv(variable);
        return (v == null || v.isBlank()) ? porDefecto : v;
    }

    private static boolean esLocal(String url) {
        String u = url.toLowerCase();
        return u.contains("localhost") || u.contains("127.0.0.1") || u.contains("://@") || u.contains("/postgres:") || u.startsWith("jdbc:postgresql://postgres");
    }

    private static String conBase(String url, String base) {
        Matcher m = URL_CON_BASE.matcher(url);
        if (!m.matches()) {
            return url;
        }
        return m.group(1) + base + (m.group(3) == null ? "" : m.group(3));
    }

    private static boolean existe(String url, String usuario, String clave) {
        try (Connection c = DriverManager.getConnection(url, usuario, clave)) {
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static void crear(String urlAdmin, String nombre, String usuario, String clave) throws Exception {
        try (Connection c = DriverManager.getConnection(urlAdmin, usuario, clave);
             Statement s = c.createStatement()) {
            s.execute("CREATE DATABASE " + nombre);
        }
    }

    /** Aplica database/schema.sql (mismo orden que el despliegue real). */
    private static void aplicarSchema(String url, String usuario, String clave) throws Exception {
        Path schema = Paths.get("..", "database", "schema.sql");
        if (!Files.exists(schema)) {
            schema = Paths.get("database", "schema.sql");
        }
        if (!Files.exists(schema)) {
            return; // en otro sistema de archivos se deja que Hibernate cree el esquema
        }
        String sql = new String(Files.readAllBytes(schema), StandardCharsets.UTF_8);
        try (Connection c = DriverManager.getConnection(url, usuario, clave);
             Statement s = c.createStatement()) {
            for (String sentencia : sql.split(";")) {
                String limpia = sentencia.trim();
                if (limpia.isEmpty() || limpia.startsWith("--")) {
                    continue;
                }
                try {
                    s.execute(limpia);
                } catch (Exception ignorada) {
                    // Si una sentencia falla (por ejemplo, un CREATE TABLE con otra sintaxis),
                    // se ignora: el contexto de Spring tambien actualiza el esquema.
                }
            }
        }
    }
}
