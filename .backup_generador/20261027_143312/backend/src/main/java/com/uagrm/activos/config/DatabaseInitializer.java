package com.uagrm.activos.config;

import com.uagrm.activos.model.Area;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.security.crypto.password.PasswordEncoder;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.model.Permiso;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.repository.AreaRepository;
import com.uagrm.activos.repository.CategoriaRepository;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.repository.RolRepository;
import com.uagrm.activos.service.DepreciacionService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Prepara la base de datos al arrancar (todo es idempotente, se puede ejecutar muchas veces):
 *  1. ajusta el esquema heredado del Sprint 1 (restriccion CHECK de estados y valores antiguos);
 *  2. crea permisos, roles, categorias y areas iniciales;
 *  3. recupera la depreciacion pendiente (el proceso mensual tambien la ejecuta).
 * Los permisos nuevos solo se asignan a los roles por defecto la primera vez que se crean,
 * de modo que lo que el administrador quite desde "Roles y permisos" no se vuelva a agregar.
 */
@Component
@Order(1)
public class DatabaseInitializer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DatabaseInitializer.class);

    private static final String[] ACCIONES = {"LEER", "CREAR", "EDITAR", "ELIMINAR"};

    /** Modulos y acciones del catalogo de permisos (Sprint 1 + Sprint 2). */
    private static final Map<String, List<String>> PERMISOS = new LinkedHashMap<>();

    /** Permisos por defecto de cada rol: modulo -> acciones. */
    private static final Map<String, Map<String, List<String>>> ROLES_POR_DEFECTO = new LinkedHashMap<>();

    private static final Map<String, String> DESCRIPCION_ROL = new LinkedHashMap<>();

    static {
        PERMISOS.put("ACTIVOS", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"));
        PERMISOS.put("DEPRECIACION", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"));
        PERMISOS.put("MANTENIMIENTO", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"));
        PERMISOS.put("PRESUPUESTO", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"));
        PERMISOS.put("REPORTES", List.of("LEER"));
        PERMISOS.put("USUARIOS", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"));

        ROLES_POR_DEFECTO.put("ADMINISTRADOR", Map.of());
        ROLES_POR_DEFECTO.put("ENCARGADO_ACTIVOS", Map.of(
                "ACTIVOS", List.of("LEER", "CREAR", "EDITAR"),
                "MANTENIMIENTO", List.of("LEER", "CREAR", "EDITAR"),
                "DEPRECIACION", List.of("LEER")));
        ROLES_POR_DEFECTO.put("CONTADOR", Map.of(
                "ACTIVOS", List.of("LEER"),
                "REPORTES", List.of("LEER"),
                "DEPRECIACION", List.of("LEER", "CREAR", "EDITAR"),
                "PRESUPUESTO", List.of("LEER")));
        ROLES_POR_DEFECTO.put("RESPONSABLE_FINANCIERO", Map.of(
                "PRESUPUESTO", List.of("LEER", "CREAR", "EDITAR")));
        ROLES_POR_DEFECTO.put("TECNICO", Map.of(
                "ACTIVOS", List.of("LEER"),
                "MANTENIMIENTO", List.of("LEER", "CREAR", "EDITAR")));

        DESCRIPCION_ROL.put("ADMINISTRADOR", "Acceso total al sistema");
        DESCRIPCION_ROL.put("ENCARGADO_ACTIVOS", "Registra, asigna y controla los activos fijos");
        DESCRIPCION_ROL.put("CONTADOR", "Consulta activos y administra la depreciación");
        DESCRIPCION_ROL.put("RESPONSABLE_FINANCIERO", "Administra presupuestos y su ejecución");
        DESCRIPCION_ROL.put("TECNICO", "Programa y registra mantenimientos");
    }

    private final JdbcTemplate jdbc;
    private final PermisoRepository permisoRepository;
    private final RolRepository rolRepository;
    private final CategoriaRepository categoriaRepository;
    private final AreaRepository areaRepository;
    private final DepreciacionService depreciacionService;
    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.superadmin.correo:superadmin@plataforma.local}")
    private String superAdminCorreo;
    @Value("${app.superadmin.password:Cambiar123!}")
    private String superAdminPassword;

    @Value("${app.depreciacion.calcular-al-iniciar:true}")
    private boolean calcularAlIniciar;

    public DatabaseInitializer(JdbcTemplate jdbc,
                               PermisoRepository permisoRepository,
                               RolRepository rolRepository,
                               CategoriaRepository categoriaRepository,
                               AreaRepository areaRepository,
                               DepreciacionService depreciacionService,
                               UsuarioRepository usuarioRepository,
                               PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.permisoRepository = permisoRepository;
        this.rolRepository = rolRepository;
        this.categoriaRepository = categoriaRepository;
        this.areaRepository = areaRepository;
        this.depreciacionService = depreciacionService;
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        // La data semilla pertenece a la empresa demo (id 1) creada por la migracion V3.
        TenantContext.setEmpresaId(1L);
        TenantContext.setCorreo("sistema");
        try {
            migrarEsquemaHeredado();
            sembrarPermisosYRoles();
            sembrarCategorias();
            sembrarAreas();
            sembrarSuperAdmin();
        } finally {
            TenantContext.limpiar();
        }
        if (calcularAlIniciar) {
            try {
                var r = depreciacionService.calcularTodos(YearMonth.now());
                log.info("Depreciación al iniciar hasta {}: {} activos, {} periodos nuevos", r.hasta(), r.activosProcesados(), r.periodosGenerados());
            } catch (Exception e) {
                log.warn("No se pudo calcular la depreciación al iniciar: {}", e.getMessage());
            }
        }
    }

    // ------------------------------------------------------------------ esquema heredado

    private void migrarEsquemaHeredado() {
        ejecutar("DO $$ DECLARE r record; BEGIN "
                + "FOR r IN SELECT conname FROM pg_constraint WHERE conrelid = to_regclass('activo') AND contype = 'c' "
                + "AND pg_get_constraintdef(oid) ILIKE '%estado%' LOOP "
                + "EXECUTE format('ALTER TABLE activo DROP CONSTRAINT %I', r.conname); "
                + "END LOOP; END $$");
        ejecutar("UPDATE activo SET estado = 'DISPONIBLE' WHERE estado = 'SIN_ASIGNAR'");
        ejecutar("UPDATE activo SET estado = 'EN_MANTENIMIENTO' WHERE estado = 'MANTENIMIENTO'");
        ejecutar("UPDATE activo SET estado = 'DADO_DE_BAJA' WHERE estado = 'BAJA'");
        ejecutar("UPDATE activo SET fecha_baja = CURRENT_DATE WHERE estado = 'DADO_DE_BAJA' AND fecha_baja IS NULL");
        ejecutar("UPDATE activo SET fecha_inicio_depreciacion = fecha_adquisicion WHERE fecha_inicio_depreciacion IS NULL");
        ejecutar("UPDATE rol SET activo = TRUE WHERE activo IS NULL");
    }

    private void ejecutar(String sql) {
        try {
            jdbc.execute(sql);
        } catch (Exception e) {
            log.warn("Ajuste de esquema omitido ({}): {}", sql.length() > 60 ? sql.substring(0, 60) + "..." : sql, e.getMessage());
        }
    }

    // ------------------------------------------------------------------ permisos y roles

    private void sembrarPermisosYRoles() {
        List<Permiso> nuevos = new ArrayList<>();
        for (Map.Entry<String, List<String>> entrada : PERMISOS.entrySet()) {
            for (String accion : entrada.getValue()) {
                if (permisoRepository.findByModuloAndAccion(entrada.getKey(), accion).isEmpty()) {
                    nuevos.add(permisoRepository.save(Permiso.builder()
                            .modulo(entrada.getKey())
                            .accion(accion)
                            .descripcion(descripcion(entrada.getKey(), accion))
                            .build()));
                }
            }
        }
        // permisos del catalogo que quedaron sin descripcion (esquema de Sprint 1)
        for (Permiso p : permisoRepository.findAll()) {
            if (p.getDescripcion() == null || p.getDescripcion().isBlank()) {
                p.setDescripcion(descripcion(p.getModulo(), p.getAccion()));
                permisoRepository.save(p);
            }
        }
        for (Map.Entry<String, Map<String, List<String>>> entrada : ROLES_POR_DEFECTO.entrySet()) {
            Rol rol = rolRepository.findByNombre(entrada.getKey()).orElse(null);
            boolean rolNuevo = rol == null;
            if (rolNuevo) {
                rol = new Rol();
                rol.setNombre(entrada.getKey());
                rol.setActivo(true);
                rol.setEsSistema(true);
                rol.setDescripcion(DESCRIPCION_ROL.get(entrada.getKey()));
                rol = rolRepository.save(rol);
            } else if (rol.getDescripcion() == null) {
                rol.setDescripcion(DESCRIPCION_ROL.get(entrada.getKey()));
            }
            // un rol recien creado recibe todos sus permisos por defecto; uno existente solo los permisos nuevos
            List<Permiso> candidatos = rolNuevo ? permisoRepository.findAll() : nuevos;
            for (Permiso permiso : candidatos) {
                if (entrada.getKey().equals("ADMINISTRADOR") || (entrada.getValue().containsKey(permiso.getModulo())
                        && entrada.getValue().get(permiso.getModulo()).contains(permiso.getAccion()))) {
                    rol.getPermisos().add(permiso);
                }
            }
            rolRepository.save(rol);
        }
    }

    private String descripcion(String modulo, String accion) {
        String objeto = switch (modulo) {
            case "ACTIVOS" -> "activos";
            case "DEPRECIACION" -> "depreciación";
            case "MANTENIMIENTO" -> "mantenimientos";
            case "PRESUPUESTO" -> "presupuestos";
            case "REPORTES" -> "reportes y estadísticas";
            case "USUARIOS" -> "usuarios";
            default -> modulo.toLowerCase();
        };
        return switch (accion) {
            case "LEER" -> "Consultar " + objeto;
            case "CREAR" -> modulo.equals("DEPRECIACION") ? "Calcular la depreciación" : "Registrar " + objeto;
            case "EDITAR" -> modulo.equals("DEPRECIACION") ? "Parametrizar la depreciación por categoría" : "Modificar " + objeto;
            case "ELIMINAR" -> modulo.equals("ACTIVOS") ? "Dar de baja activos" : "Eliminar " + objeto;
            default -> accion + " en " + modulo.toLowerCase();
        };
    }

    // ------------------------------------------------------------------ categorias y areas

    private void sembrarCategorias() {
        // Parametros iniciales (Anexo del Art. 22 del D.S. 24051). El nombre se ajusta a las categorias ya existentes.
        parametrizar("Mobiliario", 10, "0");
        parametrizar("Equipos informaticos", 4, "0");
        parametrizar("Vehiculos", 5, "0");
        parametrizar("Maquinaria", 8, "0");
        parametrizar("Inmuebles", 40, "0");
        if (categoriaRepository.findByNombre("Terrenos").isEmpty() && !categoriaRepository.existsByNombreIgnoreCase("Terrenos")) {
            Categoria terrenos = new Categoria();
            terrenos.setNombre("Terrenos");
            terrenos.setDepreciable(false);
            terrenos.setMetodoDepreciacion("LINEA_RECTA");
            terrenos.setValorResidualPct(BigDecimal.ZERO.setScale(2));
            categoriaRepository.save(terrenos);
        }
        // categorias propias sin parametros: no depreciables hasta que se configuren
        for (Categoria c : categoriaRepository.findAll()) {
            if (c.getDepreciable() == null) {
                c.setDepreciable(false);
                if (c.getMetodoDepreciacion() == null) {
                    c.setMetodoDepreciacion("LINEA_RECTA");
                }
                categoriaRepository.save(c);
            }
        }
    }

    private void parametrizar(String nombre, int vidaUtil, String residualPct) {
        categoriaRepository.findByNombre(nombre).ifPresent(c -> {
            if (c.getDepreciable() == null) {
                c.setDepreciable(true);
                c.setVidaUtil(vidaUtil);
                c.setMetodoDepreciacion("LINEA_RECTA");
                c.setValorResidualPct(new BigDecimal(residualPct).setScale(2));
                categoriaRepository.save(c);
            }
        });
    }

    private void sembrarAreas() {
        String[][] areas = {
                {"Dirección administrativa", "Administración general de la facultad"},
                {"Sistemas", "Infraestructura y soporte informático"},
                {"Laboratorios", "Laboratorios de redes y cómputo"},
                {"Biblioteca", "Biblioteca y centro de documentación"},
                {"Almacén", "Almacén central de bienes"}
        };
        for (String[] a : areas) {
            if (!areaRepository.existsByNombreIgnoreCase(a[0])) {
                areaRepository.save(Area.builder().nombre(a[0]).descripcion(a[1]).activo(true).build());
            }
        }
    }

    /**
     * HU-12: Super Admin de plataforma, sin empresa, con un rol propio de plataforma.
     * La clave se define por variable de entorno APP_SUPERADMIN_PASSWORD.
     */
    private void sembrarSuperAdmin() {
        TenantContext.limpiar(); // sin filtro de tenant: rol y usuario son de plataforma (empresa_id NULL)
        Rol rolPlataforma = rolRepository.findByNombre("SUPER_ADMIN").orElseGet(() -> {
            Rol r = new Rol();
            r.setNombre("SUPER_ADMIN");
            r.setDescripcion("Super administrador de la plataforma SaaS");
            r.setActivo(true);
            r.setEsSistema(true);
            r.setPermisos(new java.util.LinkedHashSet<>(permisoRepository.findAll()));
            return rolRepository.save(r);
        });
        if (usuarioRepository.findByCorreo(superAdminCorreo.trim().toLowerCase()).isEmpty()) {
            Usuario admin = Usuario.builder()
                    .nombre("Super Administrador")
                    .correo(superAdminCorreo.trim().toLowerCase())
                    .password(passwordEncoder.encode(superAdminPassword))
                    .rol(rolPlataforma)
                    .nivel("SUPER_ADMIN")
                    .activo(true)
                    .intentosFallidos(0)
                    .build();
            usuarioRepository.save(admin);
            log.info("Super Admin de plataforma creado: {}", superAdminCorreo);
        }
        TenantContext.setEmpresaId(1L);
        TenantContext.setCorreo("sistema");
    }
}
