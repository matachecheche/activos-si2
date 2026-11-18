package com.uagrm.activos.ia;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * HU-14: asistente de consultas en lenguaje natural. Flujo: Groq (primario),
 * Gemini (respaldo) y, si no hay claves o ambos fallan, modo guiado.
 *
 * <p>El modelo responde siempre un JSON con una de dos formas: un <b>mensaje
 * conversacional</b> (saludos, preguntas sobre el sistema, aclaraciones) o una
 * <b>especificacion de consulta</b>. Solo en el segundo caso el
 * {@link MotorConsultaSql} construye y ejecuta SQL con lista blanca y scope por
 * empresa: el LLM nunca toca SQL directamente. El prompt lleva ejemplos
 * (few-shot), ambos proveedores se fuerzan a modo JSON y se mantiene el
 * historial de la conversacion para las preguntas de seguimiento.</p>
 */
@Service
public class IaService {

    private static final Logger log = LoggerFactory.getLogger(IaService.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final int MAX_TOKENS = 2048;
    private static final int MAX_TURNOS_HISTORIAL = 8;

    private final CatalogoSql catalogo;
    private final MotorConsultaSql motor;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15)).build();

    @Value("${app.ia.groq-api-key:}")
    private String groqKey;
    @Value("${app.ia.groq-modelo:openai/gpt-oss-120b}")
    private String groqModelo;
    @Value("${app.ia.gemini-api-key:}")
    private String geminiKey;
    @Value("${app.ia.gemini-modelo:gemini-3.8-flash}")
    private String geminiModelo;

    private final IaConfigLoader configLoader;

    public IaService(CatalogoSql catalogo, MotorConsultaSql motor, IaConfigLoader configLoader) {
        this.catalogo = catalogo;
        this.motor = motor;
        this.configLoader = configLoader;
    }

    /** La clave de las properties/entorno manda; si esta vacia se usa ia_config.json. */
    private String claveGroq() {
        return groqKey != null && !groqKey.isBlank() ? groqKey.trim() : configLoader.getGroqApiKey();
    }

    private String claveGemini() {
        return geminiKey != null && !geminiKey.isBlank() ? geminiKey.trim() : configLoader.getGeminiApiKey();
    }

    private String modeloGroqEfectivo() {
        return groqKey != null && !groqKey.isBlank() ? groqModelo.trim() : configLoader.getGroqModelo();
    }

    private String modeloGeminiEfectivo() {
        return geminiKey != null && !geminiKey.isBlank() ? geminiModelo.trim() : configLoader.getGeminiModelo();
    }

    public RespuestaIa preguntar(String pregunta, List<PreguntaIaRequest.TurnoHistorial> historial) {
        String promptSistema = construirPromptSistema();
        List<PreguntaIaRequest.TurnoHistorial> historia = sanitizarHistorial(historial);
        List<String> fallos = new ArrayList<>();
        boolean habiaClaves = !claveGroq().isBlank() || !claveGemini().isBlank();

        if (!claveGroq().isBlank()) {
            if (!configLoader.formatoGroqValido() || !claveGroq().startsWith("gsk_")) {
                fallos.add("Groq: la clave guardada no tiene el formato gsk_...; obtén una clave válida en https://console.groq.com/keys");
                log.warn("Groq omitido por formato invalido de clave");
            } else {
                RespuestaIa r = intentarGroq(promptSistema, pregunta, historia, fallos);
                if (r != null) {
                    return r;
                }
            }
        }
        if (!claveGemini().isBlank()) {
            if (!configLoader.formatoGeminiValido() || !claveGemini().startsWith("AIza")) {
                fallos.add("Gemini: la clave guardada no empieza por AIza (parece un token OAuth, no una API key); crea una API key en https://aistudio.google.com/app/apikey");
                log.warn("Gemini omitido por formato invalido de clave");
            } else {
                RespuestaIa r = intentarGemini(promptSistema, pregunta, historia, fallos);
                if (r != null) {
                    return r;
                }
            }
        }
        return modoGuiado(pregunta, fallos, habiaClaves);
    }

    /**
     * Interpreta el contenido que devolvio el LLM. Es package-private para
     * poder probarlo sin llamadas HTTP: o es un mensaje conversacional o una
     * especificacion de consulta validada por el motor.
     */
    RespuestaIa interpretarContenido(String contenido, String modo) {
        String limpio = quitarFences(contenido);
        JsonNode nodo;
        try {
            nodo = MAPPER.readTree(limpio);
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "El asistente devolvio una respuesta que no se pudo interpretar");
        }
        String tipo = nodo.path("tipo").asText("consulta").trim().toLowerCase();
        if ("mensaje".equals(tipo)) {
            String texto = nodo.path("texto").asText("").trim();
            if (texto.isBlank()) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                        "El asistente devolvio un mensaje vacio");
            }
            return RespuestaIa.builder()
                    .modo(modo)
                    .explicacion(texto)
                    .sqlEjecutado(null)
                    .columnas(List.of())
                    .filas(List.of())
                    .sugerencias(List.of())
                    .diagnostico(List.of())
                    .build();
        }
        ConsultaEspec espec;
        try {
            // El campo extra 'tipo' se ignora gracias a @JsonIgnoreProperties.
            espec = MAPPER.treeToValue(nodo, ConsultaEspec.class);
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "El asistente devolvio una consulta que no se pudo interpretar");
        }
        if (espec.limite == null) {
            espec.limite = 100;
        }
        ResultadoConsulta resultado = motor.ejecutar(espec);
        return RespuestaIa.builder()
                .modo(modo)
                .explicacion(resumir(espec, resultado))
                .sqlEjecutado(resultado.sql())
                .columnas(resultado.columnas())
                .filas(resultado.filas())
                .sugerencias(List.of())
                .diagnostico(List.of())
                .build();
    }

    private RespuestaIa intentarGroq(String sistema, String usuario,
                                     List<PreguntaIaRequest.TurnoHistorial> historia, List<String> fallos) {
        try {
            String contenido = llamarGroqConRespaldo(sistema, usuario, historia);
            return interpretarContenido(contenido, "GROQ");
        } catch (ExcepcionIa e) {
            fallos.add(describirFallo("Groq", modeloGroqEfectivo(), e));
            log.warn("Groq no disponible, se intenta Gemini: {}", e.getMessage());
            return null;
        } catch (ResponseStatusException e) {
            return reintentoCorrectivo(sistema, usuario, historia, fallos, "GROQ", true);
        }
    }

    private RespuestaIa intentarGemini(String sistema, String usuario,
                                       List<PreguntaIaRequest.TurnoHistorial> historia, List<String> fallos) {
        try {
            String contenido = llamarGeminiConRespaldo(sistema, usuario, historia);
            return interpretarContenido(contenido, "GEMINI");
        } catch (ExcepcionIa e) {
            fallos.add(describirFallo("Gemini", modeloGeminiEfectivo(), e));
            log.warn("Gemini no disponible, se pasa a modo guiado: {}", e.getMessage());
            return null;
        } catch (ResponseStatusException e) {
            return reintentoCorrectivo(sistema, usuario, historia, fallos, "GEMINI", false);
        }
    }

    /** Una segunda oportunidad si el modelo devolvio texto que no es JSON valido. */
    private RespuestaIa reintentoCorrectivo(String sistema, String usuario,
                                            List<PreguntaIaRequest.TurnoHistorial> historia,
                                            List<String> fallos, String modo, boolean esGroq) {
        String corregido = usuario + "\n\nTu respuesta anterior no fue un JSON valido. Responde UNICAMENTE con "
                + "el objeto JSON del formato indicado, sin texto adicional ni marcas de markdown.";
        try {
            String contenido = esGroq
                    ? llamarGroqConRespaldo(sistema, corregido, historia)
                    : llamarGeminiConRespaldo(sistema, corregido, historia);
            return interpretarContenido(contenido, modo);
        } catch (Exception e2) {
            fallos.add(modo + ": el modelo respondio dos veces con un formato no interpretable; prueba con una "
                    + "pregunta mas concreta o reintenta en un momento. Detalle: "
                    + resumirTexto(e2.getMessage(), 160));
            log.warn("Reintento correctivo de {} fallido: {}", modo, e2.getMessage());
            return null;
        }
    }

    private List<PreguntaIaRequest.TurnoHistorial> sanitizarHistorial(List<PreguntaIaRequest.TurnoHistorial> entrada) {
        List<PreguntaIaRequest.TurnoHistorial> limpio = new ArrayList<>();
        if (entrada == null) {
            return limpio;
        }
        for (PreguntaIaRequest.TurnoHistorial t : entrada) {
            if (t == null || t.getTexto() == null || t.getTexto().isBlank()) {
                continue;
            }
            String rol = "asistente".equalsIgnoreCase(t.getRol()) ? "asistente" : "usuario";
            String texto = t.getTexto().trim();
            if (texto.length() > 1000) {
                texto = texto.substring(0, 1000);
            }
            limpio.add(new PreguntaIaRequest.TurnoHistorial(rol, texto));
        }
        if (limpio.size() > MAX_TURNOS_HISTORIAL) {
            return new ArrayList<>(limpio.subList(limpio.size() - MAX_TURNOS_HISTORIAL, limpio.size()));
        }
        return limpio;
    }

    /**
     * Diagnostico en vivo: hace una llamada minima a cada proveedor configurado
     * y devuelve el resultado con el detalle tecnico (sin exponer la clave).
     */
    public List<Map<String, Object>> probarConexion() {
        List<Map<String, Object>> resultados = new ArrayList<>();
        resultados.add(probarProveedor("Groq", claveGroq(), modeloGroqEfectivo(),
                "gsk_", "https://console.groq.com/keys", true));
        resultados.add(probarProveedor("Gemini", claveGemini(), modeloGeminiEfectivo(),
                "AIza", "https://aistudio.google.com/app/apikey", false));
        return resultados;
    }

    private Map<String, Object> probarProveedor(String nombre, String clave, String modelo,
                                                String prefijo, String urlClave, boolean esGroq) {
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("proveedor", nombre);
        r.put("modelo", modelo);
        r.put("configurado", !clave.isBlank());
        if (clave.isBlank()) {
            r.put("formatoClaveValido", false);
            r.put("ok", false);
            r.put("httpStatus", 0);
            r.put("detalle", "Sin clave configurada (configurar_ia.bat o variable de entorno).");
            return r;
        }
        boolean formatoOk = clave.startsWith(prefijo);
        r.put("formatoClaveValido", formatoOk);
        if (!formatoOk) {
            r.put("ok", false);
            r.put("httpStatus", 0);
            r.put("detalle", "La clave no empieza por '" + prefijo + "'. No es una API key valida de "
                    + nombre + "; genera una nueva en " + urlClave);
            return r;
        }
        long t0 = System.currentTimeMillis();
        try {
            if (esGroq) {
                llamarGroqConRespaldo("Responde unicamente con un objeto JSON de la forma {\"tipo\":\"mensaje\",\"texto\":\"OK\"}.",
                        "OK", List.of());
            } else {
                llamarGeminiConRespaldo("Responde unicamente con un objeto JSON de la forma {\"tipo\":\"mensaje\",\"texto\":\"OK\"}.",
                        "OK", List.of());
            }
            r.put("ok", true);
            r.put("httpStatus", 200);
            r.put("detalle", "Respuesta correcta en " + (System.currentTimeMillis() - t0) + " ms.");
        } catch (ExcepcionIa e) {
            r.put("ok", false);
            r.put("httpStatus", e.getHttpStatus());
            r.put("detalle", describirFallo(nombre, modelo, e));
        }
        return r;
    }

    private String describirFallo(String proveedor, String modelo, ExcepcionIa e) {
        String cabecera = proveedor + " (modelo " + modelo + "): ";
        if (e.getHttpStatus() == 0) {
            return cabecera + "no se pudo conectar con el servidor (revisa la conexion a internet, "
                    + "firewall o proxy). Detalle: " + e.getMessage();
        }
        if (e.getHttpStatus() == 401 || e.getHttpStatus() == 403) {
            return cabecera + "HTTP " + e.getHttpStatus() + ", la clave es invalida, esta revocada o no tiene "
                    + "permiso para este modelo. Detalle: " + e.getMessage();
        }
        if (e.isErrorDeModelo()) {
            return cabecera + "HTTP " + e.getHttpStatus() + ", el modelo no existe o no esta disponible para "
                    + "esta cuenta (los modelos viejos fueron retirados por el proveedor). Detalle: " + e.getMessage();
        }
        if (e.getHttpStatus() == 429) {
            return cabecera + "HTTP 429, se alcanzo el limite de uso del plan gratuito; reintenta en unos minutos. "
                    + "Detalle: " + e.getMessage();
        }
        return cabecera + "HTTP " + e.getHttpStatus() + ". Detalle: " + e.getMessage();
    }

    private RespuestaIa modoGuiado(String pregunta, List<String> fallos, boolean habiaClaves) {
        List<String> sugerencias = new ArrayList<>();
        sugerencias.add("Ejemplo: 'cuantos activos hay por cada estado'");
        sugerencias.add("Ejemplo: 'lista los mantenimientos con costo mayor a 1000 bolivianos'");
        sugerencias.add("Ejemplo: 'cual es la depreciacion acumulada total del periodo 2026-09'");
        sugerencias.add("Ejemplo: 'muestra los presupuestos de la gestion 2026'");
        sugerencias.add("Ejemplo: 'cuantas verificaciones de inventario resultaron NO_ENCONTRADO'");
        List<Map<String, Object>> entidades = new ArrayList<>();
        for (TablaCatalogo t : catalogo.todas()) {
            Map<String, Object> e = new LinkedHashMap<>();
            e.put("entidad", t.tabla());
            e.put("descripcion", t.descripcion());
            e.put("columnas", t.columnas().stream().map(ColumnaCatalogo::nombre).toList());
            entidades.add(e);
        }
        StringBuilder mensaje = new StringBuilder();
        if (!habiaClaves || fallos.isEmpty()) {
            mensaje.append("El asistente con inteligencia artificial no esta configurado en este servidor ")
                    .append("(falta la clave de API). Ejecute 'configurar_ia.bat' (o: python configurar_ia.py) ")
                    .append("con una clave gratuita de Groq o Gemini y reinicie el proyecto; tambien funcionan las ")
                    .append("variables GROQ_API_KEY o GEMINI_API_KEY. ");
        } else {
            mensaje.append("Las claves de IA estan configuradas, pero ningun proveedor respondio correctamente, ")
                    .append("asi que se uso el modo guiado. Detalle de los intentos: ");
            for (String f : fallos) {
                mensaje.append("\n- ").append(f).append(";");
            }
            mensaje.append("\nPasos recomendados: use el boton 'Probar conexion' de esta pantalla para ver el ")
                    .append("diagnostico en vivo; si la clave fue rechazada (HTTP 401/403), genere una nueva en ")
                    .append("consola.groq.com/keys o aistudio.google.com/app/apikey y vuelva a ejecutar ")
                    .append("configurar_ia.bat; si el error es de conexion, revise internet, firewall o proxy. ");
        }
        mensaje.append("Mientras tanto puede consultar la base de datos usando el constructor de consultas con ")
                .append("filtros. Estas son las entidades y columnas que puede preguntar.");
        return RespuestaIa.builder()
                .modo("GUIADO")
                .explicacion(mensaje.toString())
                .columnas(List.of("entidad", "descripcion", "columnas"))
                .filas(entidades.stream().map(e -> (Map<String, Object>) new LinkedHashMap<>(e)).toList())
                .sugerencias(sugerencias)
                .diagnostico(fallos)
                .build();
    }

    private String resumir(ConsultaEspec espec, ResultadoConsulta r) {
        StringBuilder sb = new StringBuilder();
        sb.append("Se consultó la entidad ").append(espec.entidad);
        int nFiltros = espec.filtros == null ? 0 : espec.filtros.size();
        if (nFiltros > 0) {
            sb.append(" aplicando ").append(nFiltros).append(nFiltros == 1 ? " filtro" : " filtros");
        }
        if (espec.agregacion != null) {
            sb.append(" con agregación ").append(espec.agregacion.funcion);
        }
        sb.append(". Se obtuvieron ").append(r.filas().size())
                .append(r.filas().size() == 1 ? " fila." : " filas.");
        if (!r.filas().isEmpty()) {
            sb.append(" Los datos se muestran en la tabla a continuación.");
        } else {
            sb.append(" No hay registros que cumplan los filtros solicitados.");
        }
        return sb.toString();
    }

    private String construirPromptSistema() {
        return """
                Eres el asistente virtual del Sistema de Gestion de Activos Fijos de la UAGRM: una
                aplicacion para administrar bienes o activos fijos, categorias, ubicaciones y areas,
                mantenimientos, depreciaciones, asignaciones a responsables, presupuestos por area,
                ejecucion presupuestaria, verificaciones fisicas de inventario y usuarios.

                Responde SIEMPRE un unico objeto JSON valido, sin texto adicional ni markdown. Tienes
                dos formatos de respuesta posibles:

                A) MENSAJE CONVERSACIONAL -> {"tipo":"mensaje","texto":"<respuesta en espanol>"}
                   Usalo para saludos, agradecimientos, despedidas, preguntas sobre que puedes hacer,
                   preguntas sobre el proyecto o el sistema, dudas generales, peticiones fuera del
                   alcance de los datos, o cuando la pregunta sea ambigua y necesites pedir una
                   aclaracion. El texto debe ser claro, amable y breve (maximo 4 frases).

                B) CONSULTA DE DATOS -> {"tipo":"consulta","entidad":"<tabla>","columnas":["<col>",...],
                   "filtros":[{"campo":"<col>","operador":"<op>","valor":<v>,"valorHasta":<v>,"valores":[...]}],
                   "orden":[{"campo":"<col>","direccion":"ASC|DESC"}],"limite":100,
                   "agregacion":{"funcion":"COUNT|SUM|AVG|MIN|MAX","campo":"<col>|*","agruparPor":["<col>"]}}
                   Usalo solo cuando el usuario pida informacion que existe en el catalogo.

                Reglas obligatorias para las consultas:
                - Usa solo las tablas y columnas de esta lista blanca; no las inventes.
                - Operadores validos: =, !=, >, >=, <, <=, LIKE, NOT LIKE, IN, BETWEEN, IS NULL, IS NOT NULL.
                - Valores numericos sin comillas; textos entre comillas; fechas como "yyyy-MM-dd".
                - Comparaciones de monedas: "mayor a 5000" significa valor > 500 en la columna monetaria correspondiente.
                - Si el usuario no pide columnas concretas, devuelve las mas utiles de la entidad.
                - Si la pregunta no se puede responder con el catalogo, usa el formato A) y explicalo amablemente.
                - En preguntas de seguimiento, usa el historial para resolver referencias como "esos",
                  "los primeros" o "y los de mantenimiento".

                Ejemplos:
                Usuario: "hola"
                {"tipo":"mensaje","texto":"Hola. Soy el asistente de activos fijos. Puedo consultar tus bienes, mantenimientos, depreciaciones y presupuestos en lenguaje natural. ¿Que necesitas saber?"}

                Usuario: "quiero saber de que va el proyecto"
                {"tipo":"mensaje","texto":"Este sistema gestiona el ciclo de vida de los activos fijos de la institucion: registro de bienes, categorias y depreciacion, ubicaciones, asignaciones, mantenimientos, inventarios fisicos y presupuestos. Puedes preguntarme por cualquiera de esos datos."}

                Usuario: "lista los activos con valor mayor a 5000"
                {"tipo":"consulta","entidad":"activo","columnas":["id","codigo","nombre","valor","estado","fecha_adquisicion"],"filtros":[{"campo":"valor","operador":">","valor":5000}],"orden":[{"campo":"valor","direccion":"DESC"}],"limite":100}

                Usuario: "cuantos activos hay por cada estado"
                {"tipo":"consulta","entidad":"activo","columnas":["estado"],"filtros":[],"orden":[],"limite":100,"agregacion":{"funcion":"COUNT","campo":"*","agruparPor":["estado"]}}

                Catalogo de tablas y columnas (la descripcion de cada columna indica su significado y,
                para los ENUM, sus valores validos):
                """ + catalogo.describir();
    }

    // ------------------------------------------------------------------
    // Llamadas a los proveedores
    // ------------------------------------------------------------------

    private String llamarGroqConRespaldo(String sistema, String usuario,
                                         List<PreguntaIaRequest.TurnoHistorial> historia) throws ExcepcionIa {
        String modelo = modeloGroqEfectivo();
        try {
            return llamarGroq(sistema, usuario, historia, modelo);
        } catch (ExcepcionIa e) {
            String reemplazo = IaConfigLoader.MODELO_GROQ_DEFECTO;
            if (e.isErrorDeModelo() && !reemplazo.equals(modelo)) {
                log.warn("Modelo Groq '{}' rechazado ({}); reintento una vez con '{}'",
                        modelo, e.getMessage(), reemplazo);
                return llamarGroq(sistema, usuario, historia, reemplazo);
            }
            throw e;
        }
    }

    private String llamarGeminiConRespaldo(String sistema, String usuario,
                                           List<PreguntaIaRequest.TurnoHistorial> historia) throws ExcepcionIa {
        String modelo = modeloGeminiEfectivo();
        try {
            return llamarGemini(sistema, usuario, historia, modelo);
        } catch (ExcepcionIa e) {
            String reemplazo = IaConfigLoader.MODELO_GEMINI_DEFECTO;
            if (e.isErrorDeModelo() && !reemplazo.equals(modelo)) {
                log.warn("Modelo Gemini '{}' rechazado ({}); reintento una vez con '{}'",
                        modelo, e.getMessage(), reemplazo);
                return llamarGemini(sistema, usuario, historia, reemplazo);
            }
            throw e;
        }
    }

    /** Groq usa roles system/user/assistant; fusiona turnos consecutivos del mismo rol. */
    private List<Map<String, Object>> mensajesGroq(String sistema, String usuario,
                                                   List<PreguntaIaRequest.TurnoHistorial> historia) {
        List<Map<String, Object>> mensajes = new ArrayList<>();
        mensajes.add(Map.of("role", "system", "content", sistema));
        String ultimoRol = "system";
        for (PreguntaIaRequest.TurnoHistorial t : historia) {
            String rol = "asistente".equals(t.getRol()) ? "assistant" : "user";
            if (rol.equals(ultimoRol)) {
                Map<String, Object> previo = mensajes.get(mensajes.size() - 1);
                previo.put("content", previo.get("content") + "\n" + t.getTexto());
            } else {
                Map<String, Object> m = new HashMap<>();
                m.put("role", rol);
                m.put("content", t.getTexto());
                mensajes.add(m);
                ultimoRol = rol;
            }
        }
        if ("user".equals(ultimoRol)) {
            Map<String, Object> previo = mensajes.get(mensajes.size() - 1);
            previo.put("content", previo.get("content") + "\n" + usuario);
        } else {
            mensajes.add(Map.of("role", "user", "content", usuario));
        }
        return mensajes;
    }

    /** Gemini exige contents alternados user/model empezando por user. */
    private List<Map<String, Object>> contentsGemini(String usuario,
                                                     List<PreguntaIaRequest.TurnoHistorial> historia) {
        List<Map<String, Object>> contents = new ArrayList<>();
        String ultimoRol = null;
        for (PreguntaIaRequest.TurnoHistorial t : historia) {
            String rol = "asistente".equals(t.getRol()) ? "model" : "user";
            if (rol.equals(ultimoRol)) {
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> partes = (List<Map<String, Object>>) contents.get(contents.size() - 1).get("parts");
                partes.add(Map.of("text", "\n" + t.getTexto()));
            } else {
                Map<String, Object> c = new HashMap<>();
                c.put("role", rol);
                c.put("parts", new ArrayList<>(List.of(Map.of("text", t.getTexto()))));
                contents.add(c);
                ultimoRol = rol;
            }
        }
        if ("user".equals(ultimoRol)) {
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> partes = (List<Map<String, Object>>) contents.get(contents.size() - 1).get("parts");
            partes.add(Map.of("text", "\n" + usuario));
        } else {
            Map<String, Object> c = new HashMap<>();
            c.put("role", "user");
            c.put("parts", new ArrayList<>(List.of(Map.of("text", usuario))));
            contents.add(c);
        }
        // Garantiza que la serie empiece por user (requisito de la API de Gemini).
        while (!contents.isEmpty() && !"user".equals(contents.get(0).get("role"))) {
            contents.remove(0);
        }
        return contents;
    }

    private String llamarGroq(String sistema, String usuario,
                              List<PreguntaIaRequest.TurnoHistorial> historia, String modelo) throws ExcepcionIa {
        Map<String, Object> body = new HashMap<>();
        body.put("model", modelo);
        body.put("temperature", 0.1);
        body.put("max_tokens", MAX_TOKENS);
        body.put("messages", mensajesGroq(sistema, usuario, historia));
        // Fuerza la salida JSON (soportado por los modelos gpt-oss de Groq).
        body.put("response_format", Map.of("type", "json_object"));
        if (modelo.startsWith("openai/gpt-oss")) {
            // Modelo de razonamiento: esfuerzo bajo para no gastar el presupuesto gratuito de tokens.
            body.put("reasoning_effort", "low");
        }
        HttpRequest req = HttpRequest.newBuilder(URI.create("https://api.groq.com/openai/v1/chat/completions"))
                .header("Authorization", "Bearer " + claveGroq())
                .header("Content-Type", "application/json")
                .timeout(Duration.ofSeconds(40))
                .POST(HttpRequest.BodyPublishers.ofString(escribirJson(body)))
                .build();
        HttpResponse<String> resp = enviar(req);
        if (resp.statusCode() / 100 != 2) {
            throwErrorProveedor("Groq", resp);
        }
        JsonNode raiz = leerJson(resp.body());
        return raiz.at("/choices/0/message/content").asText();
    }

    private String llamarGemini(String sistema, String usuario,
                                List<PreguntaIaRequest.TurnoHistorial> historia, String modelo) throws ExcepcionIa {
        Map<String, Object> body = new HashMap<>();
        body.put("systemInstruction", Map.of("parts", List.of(Map.of("text", sistema))));
        body.put("contents", contentsGemini(usuario, historia));
        // responseMimeType fuerza JSON valido en los modelos Gemini 3.x.
        body.put("generationConfig", Map.of(
                "temperature", 0.1,
                "maxOutputTokens", MAX_TOKENS,
                "responseMimeType", "application/json"));
        String url = "https://generativelanguage.googleapis.com/v1beta/models/"
                + modelo + ":generateContent?key=" + claveGemini();
        HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                .header("Content-Type", "application/json")
                .timeout(Duration.ofSeconds(40))
                .POST(HttpRequest.BodyPublishers.ofString(escribirJson(body)))
                .build();
        HttpResponse<String> resp = enviar(req);
        if (resp.statusCode() / 100 != 2) {
            throwErrorProveedor("Gemini", resp);
        }
        JsonNode raiz = leerJson(resp.body());
        return raiz.at("/candidates/0/content/parts/0/text").asText();
    }

    private HttpResponse<String> enviar(HttpRequest req) throws ExcepcionIa {
        try {
            return http.send(req, HttpResponse.BodyHandlers.ofString());
        } catch (IOException e) {
            throw new ExcepcionIa(resumirTexto(e.getMessage(), 200), 0, false);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ExcepcionIa("llamada interrumpida", 0, false);
        }
    }

    private String escribirJson(Object body) throws ExcepcionIa {
        try {
            return MAPPER.writeValueAsString(body);
        } catch (Exception e) {
            throw new ExcepcionIa("no se pudo construir la peticion: " + e.getMessage(), 0, false);
        }
    }

    private JsonNode leerJson(String cuerpo) throws ExcepcionIa {
        try {
            return MAPPER.readTree(cuerpo);
        } catch (Exception e) {
            throw new ExcepcionIa("respuesta no es JSON valido: " + resumirTexto(cuerpo, 160), 0, false);
        }
    }

    /** Extrae el mensaje legado del cuerpo de error y clasifica si el problema es el modelo. */
    private void throwErrorProveedor(String proveedor, HttpResponse<String> resp) throws ExcepcionIa {
        int status = resp.statusCode();
        String detalle = "HTTP " + status;
        boolean errorDeModelo = status == 404;
        try {
            JsonNode nodo = MAPPER.readTree(resp.body());
            String mensaje = nodo.at("/error/message").asText("");
            if (!mensaje.isBlank()) {
                detalle = resumirTexto(mensaje, 240);
            }
            String enMinusculas = detalle.toLowerCase();
            errorDeModelo = errorDeModelo
                    || enMinusculas.contains("model")
                    || enMinusculas.contains("not found")
                    || enMinusculas.contains("not supported");
        } catch (Exception ignorado) {
            // Cuerpo no JSON: nos quedamos con el codigo HTTP.
        }
        throw new ExcepcionIa(detalle, status, errorDeModelo);
    }

    private String resumirTexto(String texto, int max) {
        if (texto == null) {
            return "";
        }
        String limpio = texto.replaceAll("\\s+", " ").trim();
        return limpio.length() <= max ? limpio : limpio.substring(0, max) + "...";
    }

    private String quitarFences(String texto) {
        String t = texto.trim();
        if (t.startsWith("```")) {
            int primeraNuevaLinea = t.indexOf('\n');
            int ultimoCierre = t.lastIndexOf("```");
            if (primeraNuevaLinea > 0 && ultimoCierre > primeraNuevaLinea) {
                return t.substring(primeraNuevaLinea + 1, ultimoCierre).trim();
            }
        }
        int inicio = t.indexOf('{');
        int fin = t.lastIndexOf('}');
        if (inicio >= 0 && fin > inicio) {
            return t.substring(inicio, fin + 1);
        }
        return t;
    }
}
