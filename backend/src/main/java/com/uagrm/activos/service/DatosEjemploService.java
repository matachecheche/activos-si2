package com.uagrm.activos.service;

import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Area;
import com.uagrm.activos.model.Asignacion;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.model.ConfiguracionEmpresa;
import com.uagrm.activos.model.ConsultaGuardada;
import com.uagrm.activos.model.Cuenta;
import com.uagrm.activos.model.EjecucionPresupuestaria;
import com.uagrm.activos.model.Empresa;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.model.EstadoMantenimiento;
import com.uagrm.activos.model.EstadoPresupuesto;
import com.uagrm.activos.model.HistorialEstadoActivo;
import com.uagrm.activos.model.Mantenimiento;
import com.uagrm.activos.model.PartidaPresupuestaria;
import com.uagrm.activos.model.Presupuesto;
import com.uagrm.activos.model.ProgramacionRespaldo;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.model.TipoEjecucion;
import com.uagrm.activos.model.TipoMantenimiento;
import com.uagrm.activos.model.Ubicacion;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.model.VerificacionInventario;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.AreaRepository;
import com.uagrm.activos.repository.AsignacionRepository;
import com.uagrm.activos.repository.CategoriaRepository;
import com.uagrm.activos.repository.ConfiguracionEmpresaRepository;
import com.uagrm.activos.repository.ConsultaGuardadaRepository;
import com.uagrm.activos.repository.CuentaRepository;
import com.uagrm.activos.repository.EjecucionRepository;
import com.uagrm.activos.repository.EmpresaRepository;
import com.uagrm.activos.repository.HistorialEstadoRepository;
import com.uagrm.activos.repository.MantenimientoRepository;
import com.uagrm.activos.repository.PartidaRepository;
import com.uagrm.activos.repository.PresupuestoRepository;
import com.uagrm.activos.repository.ProgramacionRespaldoRepository;
import com.uagrm.activos.repository.RolRepository;
import com.uagrm.activos.repository.UbicacionRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.repository.VerificacionInventarioRepository;
import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.tenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Ronda 10: datos de ejemplo para TODAS las empresas.
 *
 * <p>Antes solo la empresa de demostracion (id 1) tenia informacion en todas
 * las pantallas: las demas empresas (las que se registran desde la app o el
 * portal) se quedaban con categorias vacias, sin areas, sin activos, sin
 * presupuestos, sin mantenimientos y sin inventario, y el Super Admin veia
 * empresas "en blanco". Este servicio siembra el juego completo de ejemplo
 * (categorias, areas, ubicaciones, activos, asignaciones, mantenimientos,
 * presupuesto con partidas y ejecuciones, consultas guardadas, verificaciones
 * de inventario, historial de estados, configuracion y programacion de
 * respaldo) en cualquier empresa, y solo en lo que le falta: es idempotente y
 * nunca pisa datos reales.
 *
 * <p>Se invoca:
 * <ul>
 *   <li>al registrar una empresa nueva (para que nazca con datos de ejemplo);</li>
 *   <li>al arrancar el backend, para las empresas que quedaron vacias;</li>
 *   <li>desde el despliegue, para completar las empresas existentes.</li>
 * </ul>
 */
@Service
public class DatosEjemploService {

    private static final Logger log = LoggerFactory.getLogger(DatosEjemploService.class);

    private final EmpresaRepository empresaRepository;
    private final CategoriaRepository categoriaRepository;
    private final AreaRepository areaRepository;
    private final UbicacionRepository ubicacionRepository;
    private final ActivoRepository activoRepository;
    private final AsignacionRepository asignacionRepository;
    private final MantenimientoRepository mantenimientoRepository;
    private final PresupuestoRepository presupuestoRepository;
    private final PartidaRepository partidaRepository;
    private final EjecucionRepository ejecucionRepository;
    private final ConsultaGuardadaRepository consultaGuardadaRepository;
    private final VerificacionInventarioRepository verificacionRepository;
    private final HistorialEstadoRepository historialRepository;
    private final ConfiguracionEmpresaRepository configuracionRepository;
    private final ProgramacionRespaldoRepository programacionRepository;
    private final UsuarioRepository usuarioRepository;
    private final RolRepository rolRepository;
    private final CuentaRepository cuentaRepository;
    private final PasswordEncoder passwordEncoder;
    private final DepreciacionService depreciacionService;
    private final AuditoriaService auditoriaService;
    private final PlatformTransactionManager transactionManager;

    public DatosEjemploService(EmpresaRepository empresaRepository,
                               CategoriaRepository categoriaRepository,
                               AreaRepository areaRepository,
                               UbicacionRepository ubicacionRepository,
                               ActivoRepository activoRepository,
                               AsignacionRepository asignacionRepository,
                               MantenimientoRepository mantenimientoRepository,
                               PresupuestoRepository presupuestoRepository,
                               PartidaRepository partidaRepository,
                               EjecucionRepository ejecucionRepository,
                               ConsultaGuardadaRepository consultaGuardadaRepository,
                               VerificacionInventarioRepository verificacionRepository,
                               HistorialEstadoRepository historialRepository,
                               ConfiguracionEmpresaRepository configuracionRepository,
                               ProgramacionRespaldoRepository programacionRepository,
                               UsuarioRepository usuarioRepository,
                               RolRepository rolRepository,
                               CuentaRepository cuentaRepository,
                               PasswordEncoder passwordEncoder,
                               DepreciacionService depreciacionService,
                               AuditoriaService auditoriaService,
                               PlatformTransactionManager transactionManager) {
        this.empresaRepository = empresaRepository;
        this.categoriaRepository = categoriaRepository;
        this.areaRepository = areaRepository;
        this.ubicacionRepository = ubicacionRepository;
        this.activoRepository = activoRepository;
        this.asignacionRepository = asignacionRepository;
        this.mantenimientoRepository = mantenimientoRepository;
        this.presupuestoRepository = presupuestoRepository;
        this.partidaRepository = partidaRepository;
        this.ejecucionRepository = ejecucionRepository;
        this.consultaGuardadaRepository = consultaGuardadaRepository;
        this.verificacionRepository = verificacionRepository;
        this.historialRepository = historialRepository;
        this.configuracionRepository = configuracionRepository;
        this.programacionRepository = programacionRepository;
        this.usuarioRepository = usuarioRepository;
        this.rolRepository = rolRepository;
        this.cuentaRepository = cuentaRepository;
        this.passwordEncoder = passwordEncoder;
        this.depreciacionService = depreciacionService;
        this.auditoriaService = auditoriaService;
        this.transactionManager = transactionManager;
    }

    /**
     * Completa los datos de ejemplo de una empresa. Devuelve un resumen con
     * lo que se creo. No hace nada si la empresa ya esta completa.
     */
    public Map<String, Object> completar(Long empresaId) {
        Map<String, Object> resumen = new LinkedHashMap<>();
        Long original = TenantContext.getEmpresaId();
        String correoOriginal = TenantContext.getCorreo();
        try {
            Empresa empresa = empresaRepository.findById(empresaId).orElse(null);
            if (empresa == null) {
                resumen.put("empresaId", empresaId);
                resumen.put("estado", "NO_EXISTE");
                return resumen;
            }
            Map<String, Object> creado = ejecutarConTenant(empresaId, () -> {
                Map<String, Object> r = sembrarDentroDeLaEmpresa(empresa);
                // La depreciacion de los activos de ejemplo se calcula aqui
                // mismo (misma sesion y mismo tenant).
                try {
                    depreciacionService.calcularTodos(YearMonth.now());
                } catch (Exception e) {
                    log.warn("No se pudo calcular la depreciacion de la empresa {}: {}", empresaId, e.getMessage());
                }
                return r;
            });
            resumen.putAll(creado == null ? Map.of() : creado);
            resumen.put("empresaId", empresaId);
            resumen.put("empresa", empresa.getNombre());
            resumen.put("estado", "OK");
        } catch (Exception e) {
            log.warn("No se pudieron completar los datos de ejemplo de la empresa {}: {}", empresaId, e.getMessage());
            resumen.put("empresaId", empresaId);
            resumen.put("estado", "ERROR");
            resumen.put("error", e.getMessage());
        } finally {
            TenantContext.setEmpresaId(original);
            TenantContext.setCorreo(correoOriginal);
        }
        return resumen;
    }

    /**
     * Ejecuta la siembra en un hilo propio con el tenant de la empresa.
     *
     * <p>Por que: en una peticion web, el EntityManager de la sesion
     * (open-in-view) queda atado al hilo principal y Hibernate resuelve el
     * tenant al crear esa sesion. Al abrir la transaccion nueva, Spring
     * reutiliza ese mismo EntityManager y la sesion sigue con el tenant de la
     * peticion ("assigned tenant id differs from current tenant id"), lo que
     * hacia fallar la siembra de la segunda empresa en adelante. En un hilo
     * limpio se crea una sesion nueva con el tenant correcto.
     */
    private <T> T ejecutarConTenant(Long empresaId, java.util.function.Supplier<T> tarea) {
        java.util.concurrent.CompletableFuture<T> futuro =
                java.util.concurrent.CompletableFuture.supplyAsync(() -> {
                    try {
                        TenantContext.setEmpresaId(empresaId);
                        TenantContext.setCorreo("datos-ejemplo");
                        TransactionTemplate tx = new TransactionTemplate(transactionManager);
                        tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
                        return tx.execute(estado -> tarea.get());
                    } finally {
                        TenantContext.limpiar();
                    }
                });
        try {
            return futuro.get(180, java.util.concurrent.TimeUnit.SECONDS);
        } catch (java.util.concurrent.ExecutionException e) {
            Throwable causa = e.getCause() == null ? e : e.getCause();
            if (causa instanceof RuntimeException re) {
                throw re;
            }
            throw new IllegalStateException(causa.getMessage(), causa);
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo completar los datos de ejemplo: " + e.getMessage(), e);
        }
    }

    /** Completa los datos de ejemplo de todas las empresas de la plataforma. */
    public Map<String, Object> completarTodas() {
        List<Long> ids = empresaRepository.findAll().stream()
                .map(Empresa::getId)
                .filter(id -> id != null && id > 0)
                .toList();
        List<Map<String, Object>> detalle = new ArrayList<>();
        int completadas = 0;
        for (Long id : ids) {
            Map<String, Object> r = completar(id);
            detalle.add(r);
            if (Boolean.TRUE.equals(r.get("sembrado"))) {
                completadas++;
            }
        }
        Map<String, Object> resumen = new LinkedHashMap<>();
        resumen.put("empresas", ids.size());
        resumen.put("completadas", completadas);
        resumen.put("detalle", detalle);
        return resumen;
    }

    /**
     * La siembra completa. Solo crea lo que falta: si la empresa ya tiene
     * datos en un modulo, ese modulo no se toca.
     */
    private Map<String, Object> sembrarDentroDeLaEmpresa(Empresa empresa) {
        Long empresaId = empresa.getId();
        Map<String, Object> creado = new LinkedHashMap<>();
        boolean sembrado = false;

        Map<String, Categoria> categorias = asegurarCategorias(empresaId);
        List<Area> areas = asegurarAreas(empresaId);
        List<Ubicacion> ubicaciones = asegurarUbicaciones(empresaId, areas);
        List<Usuario> usuarios = asegurarUsuariosEjemplo(empresaId);
        List<Activo> activos = asegurarActivos(empresaId, categorias, ubicaciones, usuarios);
        asegurarAsignaciones(empresaId, activos, ubicaciones, usuarios);
        asegurarMantenimientos(empresaId, activos, usuarios);
        asegurarPresupuesto(empresaId, areas, activos, usuarios);
        asegurarConsultasGuardadas(empresaId, usuarios);
        asegurarVerificaciones(empresaId, activos, usuarios);
        asegurarHistorial(empresaId, activos, usuarios);
        asegurarConfiguracion(empresaId);
        asegurarProgramacionRespaldo(empresaId);

        // El resumen se arma comparando con lo que habia antes de sembrar.
        sembrado = !activos.isEmpty() || !categorias.isEmpty() || !areas.isEmpty();
        creado.put("sembrado", sembrado);
        creado.put("categorias", categorias.size());
        creado.put("areas", areas.size());
        creado.put("ubicaciones", ubicaciones.size());
        creado.put("activos", activos.size());
        creado.put("usuariosEjemplo", usuarios.size());
        return creado;
    }

    /**
     * Filtra por empresa de forma explicita. El filtro de tenant de Hibernate
     * (@TenantId) se resuelve cuando se abre la sesion y, en una transaccion
     * nueva creada desde la plataforma, puede quedar en modo "raiz" (se ven
     * todas las empresas). Por eso las lecturas de este servicio filtran
     * siempre por empresa_id: el aislamiento lo garantiza el dato, no el marco.
     */
    private <T> List<T> deEmpresa(List<T> lista, Long empresaId, java.util.function.Function<T, Long> extractor) {
        List<T> filtrada = new ArrayList<>();
        for (T item : lista) {
            Long id = extractor.apply(item);
            if (id == null || id.equals(empresaId)) {
                filtrada.add(item);
            }
        }
        return filtrada;
    }

    private List<Categoria> categoriasDe(Long empresaId) {
        return deEmpresa(categoriaRepository.findAll(), empresaId, Categoria::getEmpresaId);
    }

    private List<Area> areasDe(Long empresaId) {
        return deEmpresa(areaRepository.findAll(), empresaId, Area::getEmpresaId);
    }

    private List<Ubicacion> ubicacionesDe(Long empresaId) {
        return deEmpresa(ubicacionRepository.findAll(), empresaId, Ubicacion::getEmpresaId);
    }

    private List<Activo> activosDe(Long empresaId) {
        return deEmpresa(activoRepository.findAll(), empresaId, Activo::getEmpresaId);
    }

    private List<Asignacion> asignacionesDe(Long empresaId) {
        return deEmpresa(asignacionRepository.findAll(), empresaId, Asignacion::getEmpresaId);
    }

    private List<Mantenimiento> mantenimientosDe(Long empresaId) {
        return deEmpresa(mantenimientoRepository.findAll(), empresaId, Mantenimiento::getEmpresaId);
    }

    private List<Presupuesto> presupuestosDe(Long empresaId) {
        return deEmpresa(presupuestoRepository.findAll(), empresaId, Presupuesto::getEmpresaId);
    }

    private List<ConsultaGuardada> consultasDe(Long empresaId) {
        return deEmpresa(consultaGuardadaRepository.findAll(), empresaId, ConsultaGuardada::getEmpresaId);
    }

    private List<VerificacionInventario> verificacionesDe(Long empresaId) {
        return deEmpresa(verificacionRepository.findAll(), empresaId, VerificacionInventario::getEmpresaId);
    }

    private List<HistorialEstadoActivo> historialDe(Long empresaId) {
        return deEmpresa(historialRepository.findAll(), empresaId, HistorialEstadoActivo::getEmpresaId);
    }

    private List<Usuario> usuariosDe(Long empresaId) {
        // aqui los usuarios sin empresa (el Super Admin de plataforma) no
        // pertenecen a la empresa, asi que se descartan.
        List<Usuario> propios = new ArrayList<>();
        for (Usuario u : usuarioRepository.findAll()) {
            if (u.getEmpresaId() != null && u.getEmpresaId().equals(empresaId)) {
                propios.add(u);
            }
        }
        return propios;
    }

    // ------------------------------------------------------------------ categorias

    private Map<String, Categoria> asegurarCategorias(Long empresaId) {
        Map<String, Categoria> mapa = new LinkedHashMap<>();
        List<Categoria> existentes = categoriasDe(empresaId);
        if (!existentes.isEmpty()) {
            for (Categoria c : existentes) {
                mapa.put(c.getNombre(), c);
            }
            return mapa;
        }
        Object[][] catalogo = {
                {"Mobiliario", 10, "0"},
                {"Equipos informaticos", 4, "0"},
                {"Vehiculos", 5, "10"},
                {"Maquinaria", 8, "5"},
                {"Inmuebles", 40, "0"},
                {"Terrenos", null, "0"},
        };
        for (Object[] fila : catalogo) {
            String nombre = (String) fila[0];
            Integer vidaUtil = (Integer) fila[1];
            String residual = (String) fila[2];
            Categoria categoria = categoriaRepository.save(Categoria.builder()
                    .empresaId(empresaId)
                    .nombre(nombre)
                    .vidaUtil(vidaUtil)
                    .metodoDepreciacion("LINEA_RECTA")
                    .valorResidualPct(new BigDecimal(residual))
                    .depreciable(vidaUtil != null)
                    .build());
            mapa.put(nombre, categoria);
        }
        return mapa;
    }

    // ------------------------------------------------------------------ areas y ubicaciones

    private List<Area> asegurarAreas(Long empresaId) {
        List<Area> areas = areasDe(empresaId);
        if (!areas.isEmpty()) {
            return areas;
        }
        Object[][] catalogo = {
                {"Administracion", "Direccion y oficinas administrativas"},
                {"Sistemas", "Computacion, redes y soporte tecnico"},
                {"Laboratorios", "Laboratorios de investigacion"},
                {"Biblioteca", "Biblioteca y archivo documental"},
                {"Almacen", "Almacen de bienes y materiales"},
        };
        for (Object[] fila : catalogo) {
            areas.add(areaRepository.save(Area.builder()
                    .empresaId(empresaId)
                    .nombre((String) fila[0])
                    .descripcion((String) fila[1])
                    .activo(true)
                    .build()));
        }
        return areas;
    }

    private List<Ubicacion> asegurarUbicaciones(Long empresaId, List<Area> areas) {
        List<Ubicacion> ubicaciones = ubicacionesDe(empresaId);
        if (!ubicaciones.isEmpty()) {
            return ubicaciones;
        }
        String[][] pares = {
                {"Oficina de Sistemas", "Sistemas"},
                {"Sala de Reuniones", "Administracion"},
                {"Laboratorio de Redes", "Laboratorios"},
                {"Biblioteca Central", "Biblioteca"},
                {"Almacen de Bienes", "Almacen"},
        };
        for (String[] par : pares) {
            Area area = areas.stream().filter(a -> par[1].equals(a.getNombre())).findFirst().orElse(null);
            ubicaciones.add(ubicacionRepository.save(Ubicacion.builder()
                    .empresaId(empresaId)
                    .nombre(par[0])
                    .area(area)
                    .build()));
        }
        return ubicaciones;
    }

    // ------------------------------------------------------------------ usuarios de ejemplo

    private List<Usuario> asegurarUsuariosEjemplo(Long empresaId) {
        List<Usuario> existentes = usuariosDe(empresaId);
        if (!existentes.isEmpty()) {
            return existentes;
        }
        List<Usuario> creados = new ArrayList<>();
        String[][] personas = {
                {"Ejemplo Encargado de Activos", "ejemplo.encargado"},
                {"Ejemplo Contador", "ejemplo.contador"},
        };
        int i = 1;
        for (String[] persona : personas) {
            String correo = persona[1] + "+" + empresaId + "@ejemplo.local";
            Cuenta cuenta = cuentaRepository.save(Cuenta.builder()
                    .correo(correo)
                    .nombre(persona[0])
                    .password(passwordEncoder.encode("Ejemplo" + empresaId + "!" + i))
                    .nivel("REGULAR")
                    .intentosFallidos(0)
                    .activo(true)
                    .build());
            Rol rol = rolRepository.findByNombre(i == 1 ? "ENCARGADO_ACTIVOS" : "CONTADOR").orElse(null);
            creados.add(usuarioRepository.save(Usuario.builder()
                    .empresaId(empresaId)
                    .cuentaId(cuenta.getId())
                    .nombre(persona[0])
                    .correo(correo)
                    .password(cuenta.getPassword())
                    .rol(rol)
                    .nivel("REGULAR")
                    .intentosFallidos(0)
                    .activo(true)
                    .build()));
            i++;
        }
        return creados;
    }

    // ------------------------------------------------------------------ activos

    private List<Activo> asegurarActivos(Long empresaId, Map<String, Categoria> categorias,
                                         List<Ubicacion> ubicaciones, List<Usuario> usuarios) {
        List<Activo> activos = activosDe(empresaId);
        if (!activos.isEmpty()) {
            return activos;
        }
        Usuario responsable = usuarios.isEmpty() ? null : usuarios.get(0);
        LocalDate hoy = LocalDate.now();
        Object[][] catalogo = {
                // nombre, categoria, valor, fechaAdquisicion, proveedor, estado, responsable, observaciones
                {"Laptop Lenovo ThinkPad 14", "Equipos informaticos", "3500", "2023-03-15", "Computadores del Oriente",
                        "EN_USO", "0", "Equipo de trabajo del area de Sistemas"},
                {"Servidor Dell PowerEdge R740", "Equipos informaticos", "38000", "2021-09-30", "Dell Bolivia",
                        "EN_USO", "0", "Servidor de la red academica"},
                {"Proyector Epson EB-X51", "Equipos informaticos", "4200", "2022-08-01", "Tecnoimport",
                        "EN_USO", "0", "Proyector de salas de reunion"},
                {"Impresora HP LaserJet M428", "Equipos informaticos", "2100", "2023-07-19", "Tecnoimport",
                        "DADO_DE_BAJA", "0", "Fuera de servicio por averia del fusor"},
                {"Escritorio de madera 1.60 m", "Mobiliario", "1800", "2021-05-10", "Muebles Andinos",
                        "EN_USO", "0", "Mobiliario de oficina"},
                {"Silla ergonomica con apoyo lumbar", "Mobiliario", "950", "2021-05-10", "Muebles Andinos",
                        "EN_USO", "0", "Silla de trabajo ergonomic"},
                {"Archivador metalico 4 gavetas", "Mobiliario", "1200", "2020-02-14", "Muebles Andinos",
                        "DISPONIBLE", "1", "En almacen, disponible para asignacion"},
                {"Toyota Corolla 2020", "Vehiculos", "185000", "2020-11-20", "Automotriz Bolivia",
                        "EN_USO", "0", "Vehiculo de la direccion"},
                {"Camioneta Ford Ranger 2019", "Vehiculos", "320000", "2019-06-05", "Automotriz Bolivia",
                        "EN_MANTENIMIENTO", "0", "En mantenimiento preventivo"},
                {"Tractor John Deere 504", "Maquinaria", "420000", "2018-03-12", "Agro Maquinaria",
                        "EN_USO", "0", "Maquinaria de apoyo a la produccion"},
                {"Edificio administrativo (2 pisos)", "Inmuebles", "2500000", "2015-01-01", "Constructora Oriental",
                        "EN_USO", "0", "Inmueble principal de la institucion"},
                {"Terreno-backend (500 m2)", "Terrenos", "800000", "2010-01-01", "Propiedades del Sur",
                        "EN_USO", "0", "Terreno sin depreciar"},
        };
        int i = 1;
        for (Object[] fila : catalogo) {
            Categoria categoria = categorias.get((String) fila[1]);
            Ubicacion ubicacion = ubicaciones.isEmpty()
                    ? null
                    : ubicaciones.get(Math.min(i - 1, ubicaciones.size() - 1));
            Usuario dueno = ((String) fila[6]).equals("1") && usuarios.size() > 1 ? usuarios.get(1) : responsable;
            LocalDate fecha = LocalDate.parse((String) fila[3]);
            BigDecimal valor = new BigDecimal((String) fila[2]);
            EstadoActivo estado = EstadoActivo.valueOf((String) fila[5]);
            Activo activo = activoRepository.save(Activo.builder()
                    .empresaId(empresaId)
                    .codigo("ACT-" + fecha.getYear() + "-" + String.format("%03d", i))
                    .nombre((String) fila[0])
                    .categoria(categoria)
                    .valor(valor)
                    .fechaAdquisicion(fecha)
                    .proveedor((String) fila[4])
                    .observaciones((String) fila[7])
                    .estado(estado)
                    .responsable(dueno)
                    .ubicacion(ubicacion)
                    .valorResidual(valor.multiply(new BigDecimal("0.05")))
                    .fechaInicioDepreciacion(fecha)
                    .fechaBaja(estado == EstadoActivo.DADO_DE_BAJA ? hoy.minusMonths(2) : null)
                    .build());
            activos.add(activo);
            i++;
        }
        return activos;
    }

    // ------------------------------------------------------------------ asignaciones

    private void asegurarAsignaciones(Long empresaId, List<Activo> activos,
                                       List<Ubicacion> ubicaciones, List<Usuario> usuarios) {
        if (!asignacionesDe(empresaId).isEmpty() || activos.isEmpty()) {
            return;
        }
        Usuario responsable = usuarios.isEmpty() ? null : usuarios.get(0);
        int i = 0;
        for (Activo activo : activos) {
            if (activo.getEstado() == EstadoActivo.DADO_DE_BAJA) {
                continue;
            }
            Usuario dueno = (i % 2 == 1 && usuarios.size() > 1) ? usuarios.get(1) : responsable;
            Ubicacion ubicacion = ubicaciones.isEmpty()
                    ? activo.getUbicacion()
                    : ubicaciones.get(i % ubicaciones.size());
            asignacionRepository.save(Asignacion.builder()
                    .empresaId(empresaId)
                    .activo(activo)
                    .responsable(dueno)
                    .ubicacion(ubicacion)
                    .fechaAsignacion(LocalDateTime.now().minusMonths(6L + i))
                    .activa(true)
                    .build());
            i++;
        }
    }

    // ------------------------------------------------------------------ mantenimientos

    private void asegurarMantenimientos(Long empresaId, List<Activo> activos, List<Usuario> usuarios) {
        if (!mantenimientosDe(empresaId).isEmpty() || activos.isEmpty()) {
            return;
        }
        Usuario tecnico = usuarios.isEmpty() ? null : usuarios.get(0);
        LocalDate hoy = LocalDate.now();
        Object[][] catalogo = {
                // indiceActivo, tipo, estado, descripcion, fecha, periodicidad, costo, tecnico
                {"9", "PREVENTIVO", "PROGRAMADO", "Mantenimiento preventivo de 250 horas", "45", "180", "850", "Taller mecanico SUR"},
                {"8", "CORRECTIVO", "EN_EJECUCION", "Cambio de kit de distribucion", "2", "", "3200", "Taller mecanico SUR"},
                {"1", "PREVENTIVO", "FINALIZADO", "Cambio de pasta termica y limpieza", "-30", "180", "350", "Soporte interno"},
                {"3", "CORRECTIVO", "FINALIZADO", "Cambio de lampara del proyector", "-20", "", "180", "Soporte interno"},
                {"2", "PREVENTIVO", "PROGRAMADO", "Revision de discos y fuentes de energia", "20", "120", "1200", "Soporte interno"},
                {"0", "CORRECTIVO", "PROGRAMADO", "Reemplazo de teclado y bateria", "-5", "", "260", "Soporte interno"},
        };
        for (Object[] fila : catalogo) {
            int indice = Integer.parseInt((String) fila[0]);
            if (indice >= activos.size()) {
                continue;
            }
            Activo activo = activos.get(indice);
            boolean preventivo = "PREVENTIVO".equals(fila[1]);
            String estado = (String) fila[2];
            int dias = Integer.parseInt((String) fila[4]);
            LocalDate fechaProgramada = hoy.plusDays(dias);
            Mantenimiento mantenimiento = mantenimientoRepository.save(Mantenimiento.builder()
                    .empresaId(empresaId)
                    .activo(activo)
                    .tipo(preventivo ? TipoMantenimiento.PREVENTIVO : TipoMantenimiento.CORRECTIVO)
                    .estado(EstadoMantenimiento.valueOf(estado))
                    .descripcion((String) fila[3])
                    .fechaProgramada(fechaProgramada)
                    .periodicidadDias(preventivo ? Integer.parseInt((String) fila[5]) : null)
                    .fechaInicio(EstadoMantenimiento.FINALIZADO.equals(estado)
                            ? fechaProgramada.plusDays(1).atStartOfDay() : null)
                    .fechaRealizada(EstadoMantenimiento.FINALIZADO.equals(estado) ? fechaProgramada.plusDays(1) : null)
                    .costo(new BigDecimal((String) fila[6]))
                    .tecnico((String) fila[7])
                    .observaciones("Orden de trabajo de ejemplo")
                    .estadoPrevioActivo(EstadoActivo.EN_USO)
                    .fechaCreacion(LocalDateTime.now().minusDays(30))
                    .creadoPor(tecnico)
                    .build());
            if (mantenimiento != null && EstadoMantenimiento.EN_EJECUCION.equals(mantenimiento.getEstado())) {
                activo.setEstado(EstadoActivo.EN_MANTENIMIENTO);
                activoRepository.save(activo);
            }
        }
    }

    // ------------------------------------------------------------------ presupuestos

    private void asegurarPresupuesto(Long empresaId, List<Area> areas, List<Activo> activos, List<Usuario> usuarios) {
        if (!presupuestosDe(empresaId).isEmpty() || areas.isEmpty()) {
            return;
        }
        Usuario aprobador = usuarios.isEmpty() ? null : usuarios.get(0);
        int gestion = YearMonth.now().getYear();
        Area area = areas.get(0);
        Presupuesto presupuesto = presupuestoRepository.save(Presupuesto.builder()
                .empresaId(empresaId)
                .area(area)
                .gestion(gestion)
                .montoAprobado(new BigDecimal("250000"))
                .estado(EstadoPresupuesto.APROBADO)
                .fechaAprobacion(LocalDateTime.now().minusMonths(2))
                .usuarioAprobador(aprobador)
                .build());

        Object[][] partidas = {
                {"5.1.01", "Equipamiento y computacion", "80000"},
                {"5.1.02", "Mantenimiento de equipos", "45000"},
                {"5.2.01", "Mobiliario y equipamiento", "60000"},
                {"5.3.01", "Software y licencias", "65000"},
        };
        List<PartidaPresupuestaria> listaPartidas = new ArrayList<>();
        for (Object[] fila : partidas) {
            listaPartidas.add(partidaRepository.save(PartidaPresupuestaria.builder()
                    .empresaId(empresaId)
                    .presupuesto(presupuesto)
                    .codigo((String) fila[0])
                    .nombre((String) fila[1])
                    .montoPlanificado(new BigDecimal((String) fila[2]))
                    .build()));
        }
        if (listaPartidas.isEmpty()) {
            return;
        }
        LocalDate hoy = LocalDate.now();
        Object[][] ejecuciones = {
                {"0", "COMPROMEISO", "Compra de 3 laptops para el area de Sistemas", "32000", "-40"},
                {"0", "EJECUCION", "Anticipo del 50% de los equipos", "16000", "-25"},
                {"1", "EJECUCION", "Mantenimiento de la flota de vehiculos", "8200", "-18"},
                {"2", "EJECUCION", "Adquisicion de mobiliario de oficina", "24500", "-9"},
                {"3", "COMPROMISO", "Licencias de software contable 2026", "31000", "-3"},
        };
        for (Object[] fila : ejecuciones) {
            int indice = Integer.parseInt((String) fila[0]);
            if (indice >= listaPartidas.size()) {
                continue;
            }
            ejecucionRepository.save(EjecucionPresupuestaria.builder()
                    .empresaId(empresaId)
                    .partida(listaPartidas.get(indice))
                    .fecha(hoy.plusDays(Integer.parseInt((String) fila[4])))
                    .concepto((String) fila[2])
                    .monto(new BigDecimal((String) fila[3]))
                    .tipo("COMPROMISO".equals(fila[1]) ? TipoEjecucion.COMPROMISO : TipoEjecucion.EJECUCION)
                    .activo(activos.isEmpty() ? null : activos.get(0))
                    .usuario(aprobador)
                    .build());
        }
    }

    // ------------------------------------------------------------------ consultas, inventario e historial

    private void asegurarConsultasGuardadas(Long empresaId, List<Usuario> usuarios) {
        if (!consultasDe(empresaId).isEmpty()) {
            return;
        }
        Long usuarioId = usuarios.isEmpty() ? null : usuarios.get(0).getId();
        String[][] consultas = {
                {"Activos por categoria", "activo",
                        "{\"tipo\":\"consulta\",\"entidad\":\"activo\",\"columnas\":[\"codigo\",\"nombre\",\"categoria\",\"valor\"]}"},
                {"Valor de la depreciacion acumulada", "depreciacion_activo",
                        "{\"tipo\":\"consulta\",\"entidad\":\"depreciacion_activo\",\"columnas\":[\"periodo\",\"valor_acumulado\"]}"},
        };
        for (String[] consulta : consultas) {
            consultaGuardadaRepository.save(ConsultaGuardada.builder()
                    .empresaId(empresaId)
                    .usuarioId(usuarioId)
                    .nombre(consulta[0])
                    .entidad(consulta[1])
                    .definicion(consulta[2])
                    .fecha(LocalDateTime.now().minusDays(10))
                    .build());
        }
    }

    private void asegurarVerificaciones(Long empresaId, List<Activo> activos, List<Usuario> usuarios) {
        if (!verificacionesDe(empresaId).isEmpty() || activos.isEmpty()) {
            return;
        }
        Long usuarioId = usuarios.isEmpty() ? null : usuarios.get(0).getId();
        String[] resultados = {"ENCONTRADO", "ENCONTRADO", "ENCONTRADO", "DIFERENCIA_ESTADO"};
        for (int i = 0; i < Math.min(4, activos.size()); i++) {
            Activo activo = activos.get(i);
            verificacionRepository.save(VerificacionInventario.builder()
                    .empresaId(empresaId)
                    .activoId(activo.getId())
                    .usuarioId(usuarioId)
                    .fechaHora(LocalDateTime.now().minusDays(2L * i).minusHours(i))
                    .latitud(-17.7833 + i * 0.0004)
                    .longitud(-63.1823 + i * 0.0003)
                    .precisionM(5.0 + i)
                    .resultado(resultados[i])
                    .observacion("ENCONTRADO".equals(resultados[i])
                            ? "Activo verificado en su ubicacion"
                            : "El activo figura en estado distinto al registrado")
                    .build());
        }
    }

    private void asegurarHistorial(Long empresaId, List<Activo> activos, List<Usuario> usuarios) {
        if (!historialDe(empresaId).isEmpty() || activos.isEmpty()) {
            return;
        }
        Usuario usuario = usuarios.isEmpty() ? null : usuarios.get(0);
        Object[][] cambios = {
                {"8", "DISPONIBLE", "EN_MANTENIMIENTO", "Ingreso a mantenimiento preventivo"},
                {"3", "EN_USO", "DADO_DE_BAJA", "Averia no reparable del fusor de impresion"},
                {"0", "DISPONIBLE", "EN_USO", "Asignado al area de Sistemas"},
        };
        for (Object[] fila : cambios) {
            int indice = Integer.parseInt((String) fila[0]);
            if (indice >= activos.size()) {
                continue;
            }
            historialRepository.save(HistorialEstadoActivo.builder()
                    .empresaId(empresaId)
                    .activo(activos.get(indice))
                    .estadoAnterior(EstadoActivo.valueOf((String) fila[1]))
                    .estadoNuevo(EstadoActivo.valueOf((String) fila[2]))
                    .motivo((String) fila[3])
                    .usuario(usuario)
                    .fecha(LocalDateTime.now().minusMonths(2L + indice))
                    .build());
        }
    }

    // ------------------------------------------------------------------ configuracion y respaldos

    private void asegurarConfiguracion(Long empresaId) {
        if (configuracionRepository.findByEmpresaId(empresaId).isPresent()) {
            return;
        }
        configuracionRepository.save(ConfiguracionEmpresa.builder()
                .empresaId(empresaId)
                .colorPrimario("#1769E0")
                .colorSecundario("#0B47A1")
                .idioma("es")
                .menuConfig("[]")
                .build());
    }

    private void asegurarProgramacionRespaldo(Long empresaId) {
        if (programacionRepository.findByEmpresaId(empresaId).isPresent()) {
            return;
        }
        programacionRepository.save(ProgramacionRespaldo.builder()
                .empresaId(empresaId)
                .frecuencia("DIARIA")
                .hora("02:00")
                .copiasAConservar(3)
                .destino("LOCAL")
                .activa(true)
                .build());
    }

    /**
     * Registra en la bitacora que se sembraron datos de ejemplo (para que el
     * Super Admin vea que la empresa quedo completa y cuando).
     */
    public void registrarEnBitacora(Long empresaId, String resumen) {
        Long original = TenantContext.getEmpresaId();
        try {
            TenantContext.setEmpresaId(empresaId);
            auditoriaService.registrar("DATOS_EJEMPLO", "EMPRESA", String.valueOf(empresaId), resumen);
        } catch (Exception e) {
            log.debug("No se pudo registrar la siembra en la bitacora: {}", e.getMessage());
        } finally {
            TenantContext.setEmpresaId(original);
        }
    }
}
