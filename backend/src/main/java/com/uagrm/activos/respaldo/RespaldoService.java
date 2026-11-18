package com.uagrm.activos.respaldo;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.model.ProgramacionRespaldo;
import com.uagrm.activos.model.Respaldo;
import com.uagrm.activos.repository.ProgramacionRespaldoRepository;
import com.uagrm.activos.repository.RespaldoRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.Types;
import java.security.MessageDigest;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * HU-16: respaldos portables (formato propio .afb), con hash SHA-256,
 * retencion configurable, destino nube opcional y restauracion
 * transaccional con respaldo de seguridad previo. No requiere pg_dump:
 * todo se hace por JDBC, asi que funciona en App Service y Neon.
 *
 * Sprint 3: el contenido del respaldo se guarda TAMBIEN en la base de datos
 * (columna `contenido`). En App Service el disco del contenedor es efimero
 * (se borra al reiniciar o al desplegar), de modo que con el archivo solo en
 * disco los respaldos desaparecian. Con el contenido en la base se pueden
 * descargar y restaurar siempre, y el archivo en disco queda como cache.
 */
@Service
public class RespaldoService {

    private static final Logger log = LoggerFactory.getLogger(RespaldoService.class);
    private static final String CABECERA = "ACTIVOS-FIJOS-BACKUP-V1";
    private static final DateTimeFormatter ARCHIVO_FMT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");
    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    /** Orden de insercion que respeta las claves foraneas. */
    static final List<String> TABLAS = List.of(
            "rol", "rol_permiso", "usuario", "categoria", "area", "ubicacion", "activo",
            "asignacion", "historial_estado_activo", "depreciacion_activo", "mantenimiento",
            "presupuesto", "partida_presupuestaria", "ejecucion_presupuestaria",
            "consulta_guardada", "configuracion_empresa", "programacion_respaldo",
            "verificacion_inventario");

    /**
     * Tablas que se archivan pero NO se restauran: son datos de facturacion.
     * Restaurarlas dejaria la suscripcion y el historial de pagos en un estado
     * incoherente con la pasarela real.
     */
    static final List<String> TABLAS_ARCHIVO = List.of("suscripcion", "pago");

    private static final Set<String> COLUMNAS_BINARIAS = Set.of("logo");
    private static final Set<String> COLUMNAS_JSONB = Set.of("menu_config", "definicion", "detalle");

    private final JdbcTemplate jdbcTemplate;
    private final RespaldoRepository respaldoRepository;
    private final ProgramacionRespaldoRepository programacionRepository;
    private final TransactionTemplate transactionTemplate;
    private final AuditoriaService auditoriaService;
    private final Path carpetaLocal;
    private final Path carpetaNube;
    private volatile Map<String, Integer> tiposColumna;

    public RespaldoService(JdbcTemplate jdbcTemplate,
                           RespaldoRepository respaldoRepository,
                           ProgramacionRespaldoRepository programacionRepository,
                           TransactionTemplate transactionTemplate,
                           AuditoriaService auditoriaService,
                           @Value("${app.respaldos.carpeta:respaldos}") String carpeta,
                           @Value("${app.respaldos.carpeta-nube:}") String carpetaNube) {
        this.jdbcTemplate = jdbcTemplate;
        this.respaldoRepository = respaldoRepository;
        this.programacionRepository = programacionRepository;
        this.transactionTemplate = transactionTemplate;
        this.auditoriaService = auditoriaService;
        // Ruta portable: relativa (respalda/respaldos) o absoluta segun la
        // configuracion. Antes apuntaba a /home/user/... que no existe ni es
        // escribible en Windows ni en el contenedor de Azure.
        this.carpetaLocal = resolver(carpeta);
        this.carpetaNube = carpetaNube == null || carpetaNube.isBlank() ? null : resolver(carpetaNube);
    }

    /** Convierte la ruta configurada en una ruta absoluta y portable. */
    static Path resolver(String carpeta) {
        if (carpeta == null || carpeta.isBlank()) {
            carpeta = "respaldos";
        }
        Path ruta = Paths.get(carpeta);
        return ruta.isAbsolute() ? ruta : Paths.get(System.getProperty("user.dir", ".")).resolve(ruta);
    }

    @SuppressWarnings("unchecked")
    public Respaldo crearRespaldoEmpresa(Long empresaId, String tipo, Long usuarioId) {
        try {
            String nombre = "respaldo_emp" + empresaId + "_" + LocalDateTime.now().format(ARCHIVO_FMT) + ".afb";

            StringBuilder contenido = new StringBuilder();
            contenido.append(CABECERA).append('\n')
                    .append("empresaId=").append(empresaId).append('\n')
                    .append("fecha=").append(LocalDateTime.now()).append('\n');
            for (String tabla : todasLasTablas()) {
                List<Map<String, Object>> filas = leerTabla(tabla, empresaId);
                contenido.append("## ").append(tabla).append('\n');
                for (Map<String, Object> fila : filas) {
                    normalizarFila(fila);
                    contenido.append(MAPPER.writeValueAsString(fila)).append('\n');
                }
            }
            byte[] bytes = contenido.toString().getBytes(StandardCharsets.UTF_8);
            String sha = sha256(bytes);

            // El archivo en disco es una cache: si el disco no esta disponible
            // (contenedor de solo lectura) el respaldo sigue siendo valido
            // porque el contenido queda en la base de datos.
            String archivo = nombre;
            String destino = "BASE";
            try {
                Files.createDirectories(carpetaLocal);
                Path archivoLocal = carpetaLocal.resolve(nombre);
                Files.write(archivoLocal, bytes);
                archivo = archivoLocal.toString();
                destino = "LOCAL";
                if (carpetaNube != null) {
                    Files.createDirectories(carpetaNube);
                    Files.copy(archivoLocal, carpetaNube.resolve(nombre), StandardCopyOption.REPLACE_EXISTING);
                    destino = "LOCAL+NUBE";
                }
            } catch (Exception e) {
                log.warn("No se pudo escribir el archivo del respaldo en disco ({}): {}",
                        carpetaLocal, e.getMessage());
                archivo = nombre;
            }

            Respaldo registro = respaldoRepository.save(Respaldo.builder()
                    .empresaId(empresaId).tipo(tipo).destino(destino).archivo(archivo)
                    .tamanoBytes(bytes.length).sha256(sha).estado("COMPLETADO")
                    .contenido(bytes)
                    .usuarioId(usuarioId).build());

            aplicarRetencion(empresaId);
            TenantContext.setEmpresaId(empresaId);
            auditoriaService.registrar("RESPALDO_" + tipo, "RESPALDO", String.valueOf(registro.getId()),
                    nombre + " sha256=" + sha);
            return registro;
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo crear el respaldo: " + e.getMessage(), e);
        } finally {
            if ("PROGRAMADO".equals(tipo)) {
                TenantContext.limpiar();
            }
        }
    }

    private List<String> todasLasTablas() {
        List<String> todas = new ArrayList<>(TABLAS);
        todas.addAll(TABLAS_ARCHIVO);
        return todas;
    }

    /** Filas de una tabla de la empresa (con los casos especiales por join). */
    private List<Map<String, Object>> leerTabla(String tabla, Long empresaId) {
        String sql = switch (tabla) {
            case "rol_permiso" -> "SELECT rp.* FROM rol_permiso rp JOIN rol r ON r.id = rp.rol_id "
                    + "WHERE r.empresa_id = ? ORDER BY rp.rol_id, rp.permiso_id";
            case "pago" -> "SELECT p.* FROM pago p JOIN suscripcion s ON s.id = p.suscripcion_id "
                    + "WHERE s.empresa_id = ? ORDER BY p.id";
            default -> "SELECT * FROM " + tabla + " WHERE empresa_id = ? ORDER BY id";
        };
        return jdbcTemplate.queryForList(sql, empresaId);
    }

    public Respaldo respaldoManual() {
        return crearRespaldoEmpresa(TenantContext.getEmpresaId(), "MANUAL", TenantContext.getUsuarioId());
    }

    /**
     * Respaldos visibles para la empresa en sesion.
     *
     * Si la empresa todavia no tiene ningun respaldo que se pueda descargar
     * (o no tiene ninguno), se crea uno real: asi la pantalla nunca queda
     * vacia y nunca muestra solo registros que fallan al descargarse.
     *
     * El respaldo se crea al abrir la pantalla, no al arrancar el backend:
     * asi su contenido incluye los datos de fabrica (semillas) y restaurarlo
     * no deja la base vacia.
     */
    public List<Respaldo> listar() {
        List<Respaldo> lista = listarSinCrear();
        boolean hayDescargable = lista.stream().anyMatch(Respaldo::isDescargable);
        if (!hayDescargable) {
            Long empresaId = TenantContext.getEmpresaId();
            if (empresaId != null) {
                try {
                    crearRespaldoEmpresa(empresaId, "MANUAL", null);
                    lista = listarSinCrear();
                } catch (Exception e) {
                    log.warn("No se pudo crear el respaldo inicial de la empresa {}: {}",
                            empresaId, e.getMessage());
                }
            }
        }
        return lista;
    }

    /** Lista los respaldos sin crear ninguno. */
    private List<Respaldo> listarSinCrear() {
        if (TenantContext.esSuperAdmin()) {
            return respaldoRepository.findAllByOrderByFechaDesc();
        }
        return respaldoRepository.findByEmpresaIdOrderByFechaDesc(TenantContext.getEmpresaId());
    }

    /** Bytes del respaldo: del archivo en disco o, si no esta, de la base. */
    public byte[] contenidoDe(Long id) {
        Respaldo r = obtenerPermitido(id);
        Path ruta = Path.of(r.getArchivo());
        try {
            if (Files.exists(ruta)) {
                return Files.readAllBytes(ruta);
            }
        } catch (Exception e) {
            log.warn("No se pudo leer el archivo del respaldo {}: {}", r.getArchivo(), e.getMessage());
        }
        if (r.getContenido() != null && r.getContenido().length > 0) {
            return r.getContenido();
        }
        throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                "Este respaldo es antiguo y no guardaba el archivo: su contenido ya no esta disponible. "
                        + "Crea un respaldo nuevo con el boton \"Crear respaldo ahora\" y ese si se puede "
                        + "descargar y restaurar.");
    }

    public String nombreArchivo(Long id) {
        Respaldo r = obtenerPermitido(id);
        String archivo = r.getArchivo();
        int i = archivo.lastIndexOf('/');
        int j = archivo.lastIndexOf('\\');
        int k = Math.max(i, j);
        return k >= 0 ? archivo.substring(k + 1) : archivo;
    }

    /** HU-16: verifica hash, toma un respaldo de seguridad y restaura dentro de una transaccion. */
    public Respaldo restaurar(Long id) {
        Respaldo r = obtenerPermitido(id);
        Long empresaId = r.getEmpresaId();
        try {
            byte[] bytes = contenidoDe(id);
            if (!sha256(bytes).equalsIgnoreCase(r.getSha256())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "El hash SHA-256 no coincide: el archivo fue alterado");
            }
            // 1) respaldo de seguridad antes de tocar datos
            Respaldo seguridad = crearRespaldoEmpresa(empresaId, "SEGURIDAD", TenantContext.getUsuarioId());

            Map<String, List<Map<String, Object>>> datos = parsear(new String(bytes, StandardCharsets.UTF_8));
            transactionTemplate.executeWithoutResult(status -> {
                List<String> reverso = new ArrayList<>(TABLAS);
                Collections.reverse(reverso);
                // Red de seguridad: la depreciacion es un dato derivado y puede
                // tener el empresa_id de otra empresa (o nulo) si se calculo
                // con otra sesion. Se borra por activo_id para que el activo
                // nunca quede con filas de depreciacion colgando (FK).
                try {
                    jdbcTemplate.update("DELETE FROM depreciacion_activo WHERE activo_id IN "
                            + "(SELECT id FROM activo WHERE empresa_id = ?)", empresaId);
                } catch (Exception e) {
                    // si la tabla no existe todavia se ignora
                }
                for (String tabla : reverso) {
                    if ("rol_permiso".equals(tabla)) {
                        jdbcTemplate.update("DELETE FROM rol_permiso WHERE rol_id IN "
                                + "(SELECT id FROM rol WHERE empresa_id = ?)", empresaId);
                    } else {
                        jdbcTemplate.update("DELETE FROM " + tabla + " WHERE empresa_id = ?", empresaId);
                    }
                }
                for (String tabla : TABLAS) {
                    for (Map<String, Object> fila : datos.getOrDefault(tabla, List.of())) {
                        insertar(tabla, fila);
                    }
                }
            });
            // 2) las secuencias de ids deben quedar por encima del maximo
            // restaurado: si no, el siguiente INSERT choca con un id existente.
            corregirSecuencias(empresaId);
            auditoriaService.registrar("RESTAURAR", "RESPALDO", String.valueOf(r.getId()),
                    "Restauracion desde " + nombreArchivo(id)
                            + "; respaldo de seguridad id=" + seguridad.getId());
            return seguridad;
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException("La restauracion fallo y se revirtio: " + e.getMessage(), e);
        }
    }

    /** Reajusta las secuencias de las tablas restauradas. */
    private void corregirSecuencias(Long empresaId) {
        for (String tabla : TABLAS) {
            if ("rol_permiso".equals(tabla)) {
                continue;
            }
            try {
                jdbcTemplate.execute("SELECT setval(pg_get_serial_sequence('" + tabla + "', 'id'), "
                        + "COALESCE((SELECT MAX(id) FROM " + tabla + "), 1), true)");
            } catch (Exception e) {
                log.warn("No se pudo corregir la secuencia de {}: {}", tabla, e.getMessage());
            }
        }
    }

    public ProgramacionRespaldo verProgramacion() {
        return programacionRepository.findByEmpresaId(TenantContext.getEmpresaId())
                .orElse(null);
    }

    public ProgramacionRespaldo guardarProgramacion(ProgramacionRespaldo entrada) {
        Long empresaId = TenantContext.getEmpresaId();
        if (!List.of("DIARIA", "SEMANAL").contains(entrada.getFrecuencia())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Frecuencia invalida (DIARIA|SEMANAL)");
        }
        ProgramacionRespaldo prog = programacionRepository.findByEmpresaId(empresaId)
                .orElseGet(() -> ProgramacionRespaldo.builder().empresaId(empresaId).build());
        prog.setFrecuencia(entrada.getFrecuencia());
        prog.setHora(entrada.getHora() == null ? "02:00" : entrada.getHora());
        prog.setCopiasAConservar(entrada.getCopiasAConservar() <= 0 ? 3 : entrada.getCopiasAConservar());
        prog.setDestino(entrada.getDestino() == null ? "LOCAL" : entrada.getDestino());
        prog.setActiva(entrada.isActiva());
        ProgramacionRespaldo guardado = programacionRepository.save(prog);
        auditoriaService.registrar("PROGRAMAR_RESPALDO", "PROGRAMACION_RESPALDO",
                String.valueOf(guardado.getId()), prog.getFrecuencia() + " " + prog.getHora());
        return guardado;
    }

    /** Lo invoca el scheduler cada hora; genera el respaldo si toca segun la programacion. */
    public void ejecutarProgramados() {
        for (ProgramacionRespaldo p : programacionRepository.findByActivaTrue()) {
            try {
                if (!tocaAhora(p)) {
                    continue;
                }
                if (yaExisteHoy(p.getEmpresaId())) {
                    continue;
                }
                log.info("Respaldo programado empresa {} ({} {})", p.getEmpresaId(), p.getFrecuencia(), p.getHora());
                TenantContext.setEmpresaId(p.getEmpresaId());
                crearRespaldoEmpresa(p.getEmpresaId(), "PROGRAMADO", null);
            } catch (Exception e) {
                log.error("Fallo el respaldo programado de la empresa {}: {}", p.getEmpresaId(), e.getMessage());
            } finally {
                TenantContext.limpiar();
            }
        }
    }

    private boolean tocaAhora(ProgramacionRespaldo p) {
        LocalDateTime ahora = LocalDateTime.now();
        String[] hm = (p.getHora() == null ? "02:00" : p.getHora()).split(":");
        boolean horaOk = ahora.getHour() == Integer.parseInt(hm[0].trim());
        if (!horaOk) {
            return false;
        }
        return switch (p.getFrecuencia()) {
            case "DIARIA" -> true;
            case "SEMANAL" -> ahora.getDayOfWeek().getValue() == 1; // lunes
            default -> false;
        };
    }

    private boolean yaExisteHoy(Long empresaId) {
        LocalDateTime inicioDia = LocalDateTime.now().toLocalDate().atStartOfDay();
        return respaldoRepository.findByEmpresaIdOrderByFechaDesc(empresaId).stream()
                .anyMatch(r -> "PROGRAMADO".equals(r.getTipo()) && r.getFecha().isAfter(inicioDia));
    }

    private void aplicarRetencion(Long empresaId) {
        ProgramacionRespaldo prog = programacionRepository.findByEmpresaId(empresaId).orElse(null);
        int conservar = prog == null ? 3 : Math.max(1, prog.getCopiasAConservar());
        List<Respaldo> todos = respaldoRepository.findByEmpresaIdOrderByFechaDesc(empresaId);
        if (todos.size() <= conservar) {
            return;
        }
        for (Respaldo viejo : todos.subList(conservar, todos.size())) {
            try {
                Files.deleteIfExists(Path.of(viejo.getArchivo()));
            } catch (Exception e) {
                log.warn("No se pudo eliminar el respaldo antiguo {}: {}", viejo.getArchivo(), e.getMessage());
            }
            // El contenido tambien vive en la base: al borrar el registro se
            // libera el espacio en Neon.
            respaldoRepository.delete(viejo);
        }
    }

    private Respaldo obtenerPermitido(Long id) {
        Respaldo r = respaldoRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Respaldo no encontrado"));
        if (!TenantContext.esSuperAdmin() && !r.getEmpresaId().equals(TenantContext.getEmpresaId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "El respaldo pertenece a otra empresa");
        }
        return r;
    }

    private Map<String, List<Map<String, Object>>> parsear(String contenido) throws Exception {
        Map<String, List<Map<String, Object>>> datos = new LinkedHashMap<>();
        String tablaActual = null;
        for (String linea : contenido.split("\n")) {
            if (linea.startsWith("## ")) {
                tablaActual = linea.substring(3).trim();
                datos.put(tablaActual, new ArrayList<>());
            } else if (tablaActual != null && linea.startsWith("{")) {
                @SuppressWarnings("unchecked")
                Map<String, Object> fila = MAPPER.readValue(linea, Map.class);
                datos.get(tablaActual).add(fila);
            }
        }
        return datos;
    }

    private void insertar(String tabla, Map<String, Object> fila) {
        List<String> columnas = new ArrayList<>(fila.keySet());
        String sql = "INSERT INTO " + tabla + " (" + String.join(",", columnas) + ") VALUES ("
                + String.join(",", columnas.stream()
                        .map(c -> COLUMNAS_JSONB.contains(c) ? "?::jsonb" : "?").toList()) + ")";
        Map<String, Integer> tipos = tiposDeColumnas();
        List<Object> valores = new ArrayList<>();
        for (String col : columnas) {
            Object valor = fila.get(col);
            if (COLUMNAS_BINARIAS.contains(col) && valor instanceof String s) {
                valores.add(Base64.getDecoder().decode(s));
            } else if (valor == null) {
                valores.add(null);
            } else {
                valores.add(convertir(tabla, col, valor, tipos.get(tabla + "." + col)));
            }
        }
        jdbcTemplate.update(sql, valores.toArray());
    }

    /** Los tipos JDBC del driver (jsonb/PGobject) se bajan a texto para que el JSON sea portable. */
    private void normalizarFila(Map<String, Object> fila) {
        for (Map.Entry<String, Object> e : fila.entrySet()) {
            Object v = e.getValue();
            if (v != null && v.getClass().getName().startsWith("org.postgresql.util.PG")) {
                try {
                    e.setValue(v.getClass().getMethod("getValue").invoke(v));
                } catch (ReflectiveOperationException ex) {
                    e.setValue(String.valueOf(v));
                }
            }
        }
    }

    /** Convierte el valor leido del JSON al tipo SQL real de la columna. */
    private Object convertir(String tabla, String col, Object valor, Integer tipo) {
        if (tipo == null || valor == null) {
            return valor;
        }
        String txt = String.valueOf(valor);
        return switch (tipo) {
            case Types.DATE -> {
                if (valor instanceof java.util.Date d) {
                    yield new java.sql.Date(d.getTime());
                }
                yield java.sql.Date.valueOf(txt.length() > 10 ? txt.substring(0, 10) : txt);
            }
            case Types.TIMESTAMP, Types.TIMESTAMP_WITH_TIMEZONE, Types.TIME, Types.TIME_WITH_TIMEZONE -> {
                if (valor instanceof java.util.Date d) {
                    yield new java.sql.Timestamp(d.getTime());
                }
                if (txt.contains("+") || txt.endsWith("Z")) {
                    yield java.sql.Timestamp.from(java.time.OffsetDateTime.parse(txt).toInstant());
                }
                yield txt.contains("T")
                        ? java.sql.Timestamp.valueOf(txt.replace('T', ' ').substring(0, Math.min(23, txt.length())))
                        : java.sql.Timestamp.valueOf(txt);
            }
            case Types.BOOLEAN, Types.BIT -> valor instanceof Boolean b ? b : Boolean.parseBoolean(txt);
            case Types.NUMERIC, Types.DECIMAL -> valor instanceof BigDecimal bd ? bd : new BigDecimal(txt);
            case Types.BIGINT -> valor instanceof Number n ? n.longValue() : Long.valueOf(txt);
            case Types.INTEGER, Types.SMALLINT, Types.TINYINT -> valor instanceof Number n ? n.intValue() : Integer.valueOf(txt);
            case Types.DOUBLE, Types.FLOAT, Types.REAL -> valor instanceof Number n ? n.doubleValue() : Double.valueOf(txt);
            default -> valor;
        };
    }

    private Map<String, Integer> tiposDeColumnas() {
        if (tiposColumna != null) {
            return tiposColumna;
        }
        Map<String, Integer> mapa = new LinkedHashMap<>();
        jdbcTemplate.execute((Connection con) -> {
            DatabaseMetaData meta = con.getMetaData();
            for (String tabla : todasLasTablas()) {
                try (ResultSet rs = meta.getColumns(con.getCatalog(), con.getSchema(), tabla, null)) {
                    while (rs.next()) {
                        mapa.put(tabla + "." + rs.getString("COLUMN_NAME"), rs.getInt("DATA_TYPE"));
                    }
                }
            }
            return null;
        });
        tiposColumna = mapa;
        return mapa;
    }

    static String sha256(byte[] entrada) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(entrada));
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 no disponible", e);
        }
    }
}
