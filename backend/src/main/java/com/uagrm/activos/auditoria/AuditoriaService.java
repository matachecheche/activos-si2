package com.uagrm.activos.auditoria;

import com.uagrm.activos.model.BitacoraAuditoria;
import com.uagrm.activos.repository.BitacoraAuditoriaRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCallback;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;

/**
 * HU-13: escribe en la bitacora inmutable. La base de datos rechaza
 * UPDATE/DELETE/TRUNCATE mediante disparador; ademas cada registro encadena
 * un hash SHA-256 del registro anterior y se duplica en un archivo append-only.
 */
@Service
public class AuditoriaService {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private final BitacoraAuditoriaRepository repo;
    private final JdbcTemplate jdbcTemplate;
    private final Path archivoLog;
    /** Cerrojo advisory de Postgres (clave fija): serializa el encadenamiento incluso con varias instancias. */
    private static final long ADVISORY_KEY = 8374629105L;

    public AuditoriaService(BitacoraAuditoriaRepository repo, JdbcTemplate jdbcTemplate,
                            @Value("${app.auditoria.archivo:/home/user/logs/auditoria_sp3.log}") String rutaLog) {
        this.repo = repo;
        this.jdbcTemplate = jdbcTemplate;
        this.archivoLog = Path.of(rutaLog);
    }

    /**
     * REQUIRES_NEW: el evento queda registrado aunque la transaccion de negocio revierta.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public BitacoraAuditoria registrar(String accion, String entidad, String entidadId, String detalle) {
        String detalleGuardado = truncar(detalle);
        // El cerrojo se libera solo al confirmar la transaccion: garantiza una cadena lineal sin bifurcaciones.
        jdbcTemplate.execute("SELECT pg_advisory_xact_lock(?)", (PreparedStatementCallback<Void>) ps -> {
            ps.setLong(1, ADVISORY_KEY);
            try (var rs = ps.executeQuery()) {
                if (rs.next()) {
                    // la funcion devuelve void; solo necesitamos adquirir el cerrojo
                }
            }
            return null;
        });
        String hashAnterior = repo.findTopByOrderByIdDesc()
                .map(BitacoraAuditoria::getHashRegistro)
                .orElse("GENESIS");
        LocalDateTime fecha = LocalDateTime.now().truncatedTo(ChronoUnit.MICROS);
        String canonico = String.join("|",
                nulo(TenantContext.getEmpresaId()), nulo(TenantContext.getCorreo()),
                accion, entidad, nulo(entidadId), nulo(detalleGuardado),
                nulo(TenantContext.getIp()), nulo(TenantContext.getEquipo()),
                fecha.format(ISO), hashAnterior);
        String hash = sha256(canonico);

        BitacoraAuditoria registro = BitacoraAuditoria.builder()
                .empresaId(TenantContext.getEmpresaId())
                .usuarioId(TenantContext.getUsuarioId())
                .usuarioNombre(TenantContext.getCorreo())
                .accion(accion)
                .entidad(entidad)
                .entidadId(entidadId)
                .detalle(detalleGuardado)
                .ip(TenantContext.getIp())
                .equipo(TenantContext.getEquipo())
                .fechaHora(fecha)
                .hashAnterior(hashAnterior)
                .hashRegistro(hash)
                .build();
        BitacoraAuditoria guardado = repo.save(registro);
        escribirArchivo(guardado);
        return guardado;
    }

    /** Recalcula la cadena de hashes; devuelve la cantidad de registros alterados (0 = integra). */
    @Transactional(readOnly = true)
    public int verificarIntegridad() {
        String previo = "GENESIS";
        int alterados = 0;
        for (BitacoraAuditoria b : repo.findAllByOrderByIdAsc()) {
            String canonico = String.join("|",
                    nulo(b.getEmpresaId()), nulo(b.getUsuarioNombre()),
                    b.getAccion(), b.getEntidad(), nulo(b.getEntidadId()), nulo(b.getDetalle()),
                    nulo(b.getIp()), nulo(b.getEquipo()),
                    b.getFechaHora().format(ISO), previo);
            String esperado = sha256(canonico);
            if (!esperado.equals(b.getHashRegistro()) || !previo.equals(b.getHashAnterior())) {
                alterados++;
            }
            previo = b.getHashRegistro();
        }
        return alterados;
    }

    private void escribirArchivo(BitacoraAuditoria b) {
        try {
            Files.createDirectories(archivoLog.getParent());
            String linea = String.join("|",
                    b.getFechaHora().format(ISO), nulo(b.getEmpresaId()), nulo(b.getUsuarioNombre()),
                    b.getAccion(), b.getEntidad(), nulo(b.getEntidadId()), b.getHashRegistro());
            Files.writeString(archivoLog, linea + System.lineSeparator(),
                    StandardCharsets.UTF_8, StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (Exception e) {
            // La bitacora en BD ya se guardo; el archivo es una capa adicional.
            System.err.println("[AUDITORIA] No se pudo escribir el log en archivo: " + e.getMessage());
        }
    }

    private static String nulo(Object valor) {
        return valor == null ? "" : String.valueOf(valor);
    }

    private static String truncar(String texto) {
        if (texto == null) {
            return null;
        }
        return texto.length() > 2000 ? texto.substring(0, 2000) : texto;
    }

    private static String sha256(String entrada) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(entrada.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo calcular SHA-256", e);
        }
    }
}
