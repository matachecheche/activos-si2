package com.uagrm.activos.ia;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Resuelve las claves y modelos de la IA combinando dos fuentes:
 * <ol>
 *   <li>variables de entorno (GROQ_API_KEY, GEMINI_API_KEY, ...), que tienen
 *       prioridad y son las que inyecta el lanzador desde ia_config.json;</li>
 *   <li>el archivo ia_config.json creado por configurar_ia.bat, leido aqui como
 *       respaldo para que la IA funcione aunque el arranque no propague el
 *       entorno (JAR ejecutado a mano, IDE, servicios de Windows, etc.).</li>
 * </ol>
 * El archivo se busca en la carpeta actual, en la carpeta padre (el backend
 * corre desde backend/ con 'mvn spring-boot:run') y dos niveles arriba; la
 * variable APP_IA_CONFIG_FILE permite indicar una ruta explicita.
 *
 * <p>Ademas migra automaticamente los modelos que los proveedores retiraron
 * (Groq apago llama-3.3-70b-versatile el 2026-08-16; Gemini los 1.5/2.0 ya no
 * existen), de modo que un ia_config.json creado con versiones viejas se
 * autocorrija sin que el usuario tenga que reconfigurar nada.</p>
 */
@Component
public class IaConfigLoader {

    private static final Logger log = LoggerFactory.getLogger(IaConfigLoader.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /** Modelos vigentes en octubre de 2026 para el plan gratuito (sin tarjeta). */
    public static final String MODELO_GROQ_DEFECTO = "openai/gpt-oss-120b";
    public static final String MODELO_GROQ_RESPALDO = "openai/gpt-oss-20b";
    public static final String MODELO_GEMINI_DEFECTO = "gemini-3.8-flash";
    public static final String MODELO_GEMINI_RESPALDO = "gemini-3.5-flash-lite";

    /** Modelos retirados o que requieren plan Enterprise -> reemplazo vigente. */
    private static final Map<String, String> MODELOS_RETIRADOS = Map.ofEntries(
            Map.entry("llama-3.3-70b-versatile", MODELO_GROQ_DEFECTO),
            Map.entry("llama-3.1-8b-instant", MODELO_GROQ_RESPALDO),
            Map.entry("mixtral-8x7b-32768", MODELO_GROQ_DEFECTO),
            Map.entry("qwen/qwen3-32b", MODELO_GROQ_DEFECTO),
            Map.entry("qwen/qwen3.6-27b", MODELO_GROQ_DEFECTO),
            Map.entry("gemini-1.5-flash", MODELO_GEMINI_DEFECTO),
            Map.entry("gemini-1.5-flash-8b", MODELO_GEMINI_DEFECTO),
            Map.entry("gemini-1.5-pro", MODELO_GEMINI_DEFECTO),
            Map.entry("gemini-2.0-flash", MODELO_GEMINI_DEFECTO),
            Map.entry("gemini-2.0-flash-lite", MODELO_GEMINI_RESPALDO),
            Map.entry("gemini-pro", MODELO_GEMINI_DEFECTO));

    @Value("${app.ia.config-file:}")
    private String rutaConfigurada;

    private JsonNode archivo = null;
    private Path archivoUsado = null;

    @PostConstruct
    void cargar() {
        Path ruta = localizarArchivo();
        if (ruta != null) {
            try {
                archivo = MAPPER.readTree(Files.readAllBytes(ruta));
                archivoUsado = ruta;
                log.info("Configuracion de IA leida desde {}", ruta.toAbsolutePath());
            } catch (Exception e) {
                log.warn("No se pudo leer {}: {}", ruta, e.getMessage());
            }
        }
        log.info("Estado de la IA al arrancar: Groq={}, Gemini={}, fuente={}",
                estaGroq() ? "configurado" : "sin clave",
                estaGemini() ? "configurado" : "sin clave",
                (!getGroqApiKey().isBlank() || !getGeminiApiKey().isBlank()) ? describirFuente() : "ninguna (modo guiado)");
        String groqViejo = resolver("GROQ_MODEL", "groq_modelo");
        if (!groqViejo.isBlank() && MODELOS_RETIRADOS.containsKey(groqViejo.trim())) {
            log.warn("El modelo Groq '{}' fue retirado por el proveedor; se usa automaticamente '{}'",
                    groqViejo.trim(), getGroqModelo());
        }
        String geminiViejo = resolver("GEMINI_MODEL", "gemini_modelo");
        if (!geminiViejo.isBlank() && MODELOS_RETIRADOS.containsKey(geminiViejo.trim())) {
            log.warn("El modelo Gemini '{}' fue retirado por el proveedor; se usa automaticamente '{}'",
                    geminiViejo.trim(), getGeminiModelo());
        }
    }

    private Path localizarArchivo() {
        String explicita = rutaConfigurada != null && !rutaConfigurada.isBlank()
                ? rutaConfigurada : System.getenv("APP_IA_CONFIG_FILE");
        if (explicita != null && !explicita.isBlank()) {
            Path p = Paths.get(explicita);
            return Files.isRegularFile(p) ? p : null;
        }
        String dir = System.getProperty("user.dir", ".");
        for (Path candidato : new Path[] {
                Paths.get(dir, "ia_config.json"),
                Paths.get(dir, "..", "ia_config.json"),
                Paths.get(dir, "..", "..", "ia_config.json")
        }) {
            if (Files.isRegularFile(candidato)) {
                return candidato;
            }
        }
        return null;
    }

    private String textoArchivo(String clave) {
        if (archivo == null) {
            return "";
        }
        JsonNode nodo = archivo.get(clave);
        return nodo == null || nodo.isNull() ? "" : nodo.asText("");
    }

    /** La variable de entorno gana al archivo; si no existe, se usa el archivo. */
    private String resolver(String variableEntorno, String claveArchivo) {
        String entorno = System.getenv(variableEntorno);
        if (entorno != null && !entorno.isBlank()) {
            return entorno.trim();
        }
        return textoArchivo(claveArchivo).trim();
    }

    /** Si el modelo pedido ya fue retirado, devuelve su reemplazo vigente. */
    private String modeloVigente(String modelo, String defecto) {
        if (modelo == null || modelo.isBlank()) {
            return defecto;
        }
        String limpio = modelo.trim();
        return MODELOS_RETIRADOS.getOrDefault(limpio, limpio);
    }

    public String getGroqApiKey() {
        return resolver("GROQ_API_KEY", "groq_api_key");
    }

    public String getGeminiApiKey() {
        return resolver("GEMINI_API_KEY", "gemini_api_key");
    }

    public String getGroqModelo() {
        return modeloVigente(resolver("GROQ_MODEL", "groq_modelo"), MODELO_GROQ_DEFECTO);
    }

    public String getGeminiModelo() {
        return modeloVigente(resolver("GEMINI_MODEL", "gemini_modelo"), MODELO_GEMINI_DEFECTO);
    }

    public boolean estaGroq() {
        return !getGroqApiKey().isBlank();
    }

    public boolean estaGemini() {
        return !getGeminiApiKey().isBlank();
    }

    /** Las claves Groq empiezan por gsk_; cualquier otra cosa no funcionara. */
    public boolean formatoGroqValido() {
        String k = getGroqApiKey();
        return k.isBlank() || k.startsWith("gsk_");
    }

    /** Las API keys de Gemini empiezan por AIza; AQ./ya29. son tokens OAuth, no API keys. */
    public boolean formatoGeminiValido() {
        String k = getGeminiApiKey();
        return k.isBlank() || k.startsWith("AIza");
    }

    /** Dice de donde salio cada clave, sin revelar el contenido. */
    public Map<String, Object> estado() {
        Map<String, Object> estado = new LinkedHashMap<>();
        estado.put("groqConfigurado", estaGroq());
        estado.put("geminiConfigurado", estaGemini());
        estado.put("groqFormatoValido", formatoGroqValido());
        estado.put("geminiFormatoValido", formatoGeminiValido());
        estado.put("modeloGroq", getGroqModelo());
        estado.put("modeloGemini", getGeminiModelo());
        estado.put("fuente", describirFuente());
        estado.put("archivoConfig", archivoUsado == null ? null : archivoUsado.getFileName().toString());
        return estado;
    }

    private String describirFuente() {
        boolean groqEntorno = System.getenv("GROQ_API_KEY") != null && !System.getenv("GROQ_API_KEY").isBlank();
        boolean geminiEntorno = System.getenv("GEMINI_API_KEY") != null && !System.getenv("GEMINI_API_KEY").isBlank();
        if (groqEntorno || geminiEntorno) {
            return archivo != null ? "variables de entorno y archivo ia_config.json" : "variables de entorno";
        }
        return archivo != null ? "archivo ia_config.json" : "ninguna";
    }
}
