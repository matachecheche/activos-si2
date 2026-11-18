package com.uagrm.activos.saas;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.dto.RegistroEmpresaRequest;
import com.uagrm.activos.dto.RegistroEmpresaResponse;
import com.uagrm.activos.model.*;
import com.uagrm.activos.repository.*;
import com.uagrm.activos.service.DatosEjemploService;
import com.uagrm.activos.tenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.*;

/**
 * HU-11: registro publico de una empresa y provisionamiento transaccional de
 * todo su workspace: empresa, configuracion, suscripcion, pago sandbox,
 * roles por defecto y usuario administrador.
 */
@Service
public class RegistroEmpresaService {

    private static final Logger log = LoggerFactory.getLogger(RegistroEmpresaService.class);

    private static final String PASSWORD_POLICY =
            "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z\\d]).{8,}$";
    private static final SecureRandom RANDOM = new SecureRandom();

    /**
     * Dias de prueba gratuita que se dan al registrar una empresa. El cobro
     * real se hace despues, en la pantalla de suscripcion, con la pasarela
     * configurada (Mercado Pago o PayPal). Aqui NO se simula ningun pago.
     */
    private static final int DIAS_PRUEBA = 15;

    private final EmpresaRepository empresaRepository;
    private final PlanRepository planRepository;
    private final SuscripcionRepository suscripcionRepository;
    private final PagoRepository pagoRepository;
    private final ConfiguracionEmpresaRepository configuracionRepository;
    private final RolRepository rolRepository;
    private final PermisoRepository permisoRepository;
    private final UsuarioRepository usuarioRepository;
    private final com.uagrm.activos.repository.CuentaRepository cuentaRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditoriaService auditoriaService;
    private final DatosEjemploService datosEjemploService;
    private final com.uagrm.activos.pagos.PagosService pagosService;
    private final PlatformTransactionManager transactionManager;

    public RegistroEmpresaService(EmpresaRepository empresaRepository, PlanRepository planRepository,
                                  SuscripcionRepository suscripcionRepository, PagoRepository pagoRepository,
                                  ConfiguracionEmpresaRepository configuracionRepository,
                                  RolRepository rolRepository, PermisoRepository permisoRepository,
                                  UsuarioRepository usuarioRepository,
                                  com.uagrm.activos.repository.CuentaRepository cuentaRepository,
                                  PasswordEncoder passwordEncoder,
                                  AuditoriaService auditoriaService,
                                  DatosEjemploService datosEjemploService,
                                  com.uagrm.activos.pagos.PagosService pagosService,
                                  PlatformTransactionManager transactionManager) {
        this.empresaRepository = empresaRepository;
        this.planRepository = planRepository;
        this.suscripcionRepository = suscripcionRepository;
        this.pagoRepository = pagoRepository;
        this.configuracionRepository = configuracionRepository;
        this.rolRepository = rolRepository;
        this.permisoRepository = permisoRepository;
        this.usuarioRepository = usuarioRepository;
        this.cuentaRepository = cuentaRepository;
        this.passwordEncoder = passwordEncoder;
        this.auditoriaService = auditoriaService;
        this.datosEjemploService = datosEjemploService;
        this.pagosService = pagosService;
        this.transactionManager = transactionManager;
    }

    @Transactional
    public RegistroEmpresaResponse registrar(RegistroEmpresaRequest req) {
        String correoAdmin = req.getCorreoAdmin().trim().toLowerCase();
        validar(req, correoAdmin);
        return crear(req, correoAdmin, req.getNombreAdmin(), req.getPasswordAdmin());
    }

    /**
     * Ronda 11: abre el cobro del plan elegido al crear la empresa.
     *
     * <p>Se llama DESPUES de que el alta se haya confirmado: el checkout
     * (Stripe, QR o transferencia bancaria) se crea en su propia transaccion
     * y, si la pasarela no esta configurada, la empresa conserva su prueba
     * gratuita y se devuelve el motivo del fallo (nunca se simula un
     * pago).</p>
     */
    public RegistroEmpresaResponse abrirCobro(RegistroEmpresaResponse respuesta, RegistroEmpresaRequest req) {
        if (respuesta == null || req == null || respuesta.getEmpresaId() == null) {
            return respuesta;
        }
        String metodo = req.getMetodoPago() == null ? "" : req.getMetodoPago().trim().toUpperCase(Locale.ROOT);
        if (metodo.isBlank() || "PRUEBA".equals(metodo) || "TARJETA_SANDBOX".equals(metodo)) {
            return respuesta;
        }
        Map<String, Object> cobro = new LinkedHashMap<>();
        try {
            cobro = pagosService.crearCheckoutParaEmpresa(respuesta.getEmpresaId(), req.getPlanId(),
                    req.getMeses(), req.getCorreoAdmin(), metodo);
        } catch (ResponseStatusException e) {
            log.warn("No se pudo abrir el cobro de la empresa {}: {}", respuesta.getEmpresaId(), e.getMessage());
            cobro.put("mensajePago", e.getReason() == null ? e.getMessage() : e.getReason());
        } catch (Exception e) {
            log.warn("No se pudo abrir el cobro de la empresa {}: {}", respuesta.getEmpresaId(), e.getMessage());
            cobro.put("mensajePago", "No se pudo abrir el cobro: " + e.getMessage());
        }
        if (cobro.isEmpty()) {
            return respuesta;
        }
        // Si el cobro no se pudo abrir (pasarela sin credenciales), la empresa
        // conserva su prueba gratuita y se explica el motivo.
        boolean abierto = cobro.get("referencia") != null || cobro.get("checkoutUrl") != null
                || cobro.get("datosBancarios") != null;
        if (!abierto) {
            if (cobro.get("mensajePago") != null) {
                respuesta.setMensajePago(String.valueOf(cobro.get("mensajePago")));
            }
            return respuesta;
        }
        respuesta.setEstadoPago("PENDIENTE");
        if (cobro.get("referencia") != null) {
            respuesta.setReferenciaPago(String.valueOf(cobro.get("referencia")));
        }
        if (cobro.get("checkoutUrl") != null) {
            respuesta.setCheckoutUrl(String.valueOf(cobro.get("checkoutUrl")));
        }
        if (cobro.get("qrImagen") != null) {
            respuesta.setQrImagen(String.valueOf(cobro.get("qrImagen")));
        }
        if (cobro.get("datosBancarios") instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, String> banco = new LinkedHashMap<>((Map<String, String>) cobro.get("datosBancarios"));
            respuesta.setDatosBancarios(banco);
        }
        if (cobro.get("instrucciones") != null) {
            respuesta.setInstrucciones(String.valueOf(cobro.get("instrucciones")));
        }
        if (cobro.get("monto") != null) {
            respuesta.setMonto(new BigDecimal(cobro.get("monto").toString()));
        }
        if (cobro.get("mensajePago") != null) {
            respuesta.setMensajePago(String.valueOf(cobro.get("mensajePago")));
        }
        respuesta.setPagoDisponible(respuesta.getCheckoutUrl() != null
                || respuesta.getDatosBancarios() != null
                || respuesta.getQrImagen() != null);
        return respuesta;
    }

    /**
     * Ronda 10: siembra los datos de ejemplo de la empresa (categorias, areas,
     * ubicaciones, activos, asignaciones, mantenimiento, presupuesto con
     * partidas y ejecuciones, consultas guardadas, inventario, historial,
     * configuracion y programacion de respaldo). Se invoca DESPUES del alta,
     * cuando la transaccion ya confirmo, para que la empresa nueva no tenga
     * ninguna pantalla vacia. Es idempotente: solo completa lo que falta.
     */
    public void sembrarDatosEjemplo(Long empresaId) {
        if (empresaId == null) {
            return;
        }
        try {
            Map<String, Object> resumen = datosEjemploService.completar(empresaId);
            log.info("Datos de ejemplo de la empresa {}: {}", empresaId, resumen.get("estado"));
        } catch (Exception e) {
            // La siembra es un extra: si falla, el alta de la empresa sigue.
            log.warn("No se pudieron sembrar los datos de ejemplo de la empresa {}: {}", empresaId, e.getMessage());
        }
    }

    /**
     * Sprint 3 / multiempresa: agrega una empresa a la cuenta que ya esta
     * autenticada (sin pedir contrasena: la identidad es la misma cuenta
     * global). El usuario queda como administrador de la empresa nueva y puede
     * cambiar a ella desde el selector de empresa.
     */
    @Transactional
    public RegistroEmpresaResponse registrarParaCuenta(RegistroEmpresaRequest req, String correoCuenta,
                                                       String nombreCuenta) {
        String correo = correoCuenta.trim().toLowerCase();
        // El alta ocurre fuera de cualquier tenant (igual que el registro publico).
        TenantContext.setEmpresaId(null);
        if (cuentaRepository.findByCorreo(correo).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La cuenta del usuario no existe. Inicie sesion nuevamente.");
        }
        if (req.getNit() != null && !req.getNit().isBlank()
                && empresaRepository.existsByNit(req.getNit().trim())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe una empresa con ese NIT");
        }
        if (req.getNombreEmpresa() == null || req.getNombreEmpresa().trim().length() < 3) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "El nombre de la empresa debe tener al menos 3 caracteres");
        }
        if (req.getCorreoContacto() == null || req.getCorreoContacto().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "El correo de contacto de la empresa es obligatorio");
        }
        // La contrasena no se pide: es la misma cuenta global del usuario.
        //
        // El alta corre en una transaccion NUEVA: Hibernate fija el tenant de
        // la sesion al abrirla, y la sesion de la peticion ya viene con la
        // empresa del usuario (empresa_id != 0). Con esa sesion, Hibernate
        // rechaza guardar los roles de la empresa nueva ("assigned tenant id
        // differs from current tenant id"). En una transaccion nueva el
        // contexto va vacio (ROOT) y el alta se puede hacer con normalidad.
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        return tx.execute(estado -> crear(req, correo,
                nombreCuenta == null || nombreCuenta.isBlank() ? "Administrador" : nombreCuenta, null));
    }

    private RegistroEmpresaResponse crear(RegistroEmpresaRequest req, String correoAdmin,
                                          String nombreAdmin, String passwordAdmin) {
        Plan plan = planRepository.findById(req.getPlanId())
                .filter(Plan::isActivo)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "El plan seleccionado no existe o no esta disponible"));

        TenantContext.setEmpresaId(null); // el alta ocurre fuera de cualquier tenant
        Empresa empresa = empresaRepository.save(Empresa.builder()
                .nombre(req.getNombreEmpresa().trim())
                .nit(req.getNit() == null || req.getNit().isBlank() ? null : req.getNit().trim())
                .rubro(req.getRubro())
                .correoContacto(req.getCorreoContacto().trim().toLowerCase())
                .estado(EstadoEmpresa.ACTIVA)
                .build());

        TenantContext.setEmpresaId(empresa.getId()); // @TenantId rellena las entidades del workspace
        configuracionRepository.save(ConfiguracionEmpresa.builder()
                .empresaId(empresa.getId())
                .menuConfig("[]")
                .build());

        Map<String, Rol> roles = provisionarRoles(empresa.getId());

        // Identidad global de la persona (permite que la misma cuenta
        // entre a mas de una empresa con un solo login).
        com.uagrm.activos.model.Cuenta cuenta = cuentaRepository.findByCorreo(correoAdmin)
                .orElseGet(() -> cuentaRepository.save(com.uagrm.activos.model.Cuenta.builder()
                        .correo(correoAdmin)
                        .nombre(nombreAdmin.trim())
                        .password(passwordEncoder.encode(passwordAdmin))
                        .nivel("ADMIN")
                        .intentosFallidos(0)
                        .activo(true)
                        .build()));

        Usuario admin = Usuario.builder()
                .empresaId(empresa.getId())
                .cuentaId(cuenta.getId())
                .nombre(nombreAdmin.trim())
                .correo(correoAdmin)
                .password(cuenta.getPassword())
                .rol(roles.get("ADMINISTRADOR"))
                .nivel("ADMIN")
                .intentosFallidos(0)
                .activo(true)
                .build();
        usuarioRepository.save(admin);

        LocalDateTime ahora = LocalDateTime.now();
        Suscripcion suscripcion = suscripcionRepository.save(Suscripcion.builder()
                .empresa(empresa)
                .plan(plan)
                .fechaInicio(ahora)
                .fechaVencimiento(ahora.plusDays(DIAS_PRUEBA))
                .estado(EstadoSuscripcion.ACTIVA)
                .fechaEstado(ahora)
                .build());

        // No se registra ningun pago simulado: la empresa entra con una prueba
        // gratuita de DIAS_PRUEBA dias y el cobro real se hace DESPUES, con la
        // pasarela elegida por el usuario (ver abrirCobro). El cobro se abre
        // fuera de esta transaccion: si la pasarela falla, la empresa ya esta
        // creada y solo se informa el motivo (nunca se simula un cobro).
        String referencia = "PRUEBA-" + Long.toHexString(RANDOM.nextLong()).toUpperCase(Locale.ROOT);
        String metodoPago = req.getMetodoPago() == null ? "" : req.getMetodoPago().trim().toUpperCase(Locale.ROOT);

        TenantContext.setEmpresaId(empresa.getId());
        TenantContext.setCorreo(correoAdmin);
        auditoriaService.registrar("REGISTRO_EMPRESA", "EMPRESA", String.valueOf(empresa.getId()),
                "Alta de empresa con plan " + plan.getNombre() + " por " + req.getMeses() + " mes(es)");
        TenantContext.limpiar();

        return RegistroEmpresaResponse.builder()
                .empresaId(empresa.getId())
                .nombreEmpresa(empresa.getNombre())
                .estado(empresa.getEstado().name())
                .suscripcionId(suscripcion.getId())
                .plan(plan.getNombre())
                .vencimiento(suscripcion.getFechaVencimiento())
                .referenciaPago(referencia)
                .estadoPago("PRUEBA_GRATUITA")
                .correoAdmin(correoAdmin)
                .metodoPago(metodoPago)
                .pagoDisponible(false)
                .mensaje("Empresa registrada con " + DIAS_PRUEBA + " dias de prueba del plan "
                        + plan.getNombre() + ". Ya puede iniciar sesion con el correo del "
                        + "administrador; para renovar, contracted desde la pantalla de suscripcion.")
                .build();
    }

    private void validar(RegistroEmpresaRequest req, String correoAdmin) {
        // Multiempresa: la misma persona puede registrar mas de una empresa
        // con su correo (queda como administrador de todas). Lo unico que no
        // se permite es repetir el NIT de una empresa ya registrada.
        if (req.getNit() != null && !req.getNit().isBlank()
                && empresaRepository.existsByNit(req.getNit().trim())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe una empresa con ese NIT");
        }
        if (req.getPasswordAdmin() == null || !req.getPasswordAdmin().matches(PASSWORD_POLICY)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La contrasena del administrador debe tener minimo 8 caracteres, mayuscula, minuscula, numero y caracter especial");
        }
    }

    /** Crea los cinco roles por defecto con sus permisos; ADMINISTRADOR recibe todos. */
    private Map<String, Rol> provisionarRoles(Long empresaId) {
        List<Permiso> todos = permisoRepository.findAll();
        Map<String, List<String>> defecto = new LinkedHashMap<>();
        defecto.put("ENCARGADO_ACTIVOS", List.of("ACTIVOS_LEER", "ACTIVOS_CREAR", "ACTIVOS_EDITAR",
                "MANTENIMIENTO_LEER", "MANTENIMIENTO_CREAR", "MANTENIMIENTO_EDITAR", "DEPRECIACION_LEER"));
        defecto.put("CONTADOR", List.of("ACTIVOS_LEER", "REPORTES_LEER", "DEPRECIACION_LEER",
                "DEPRECIACION_CREAR", "DEPRECIACION_EDITAR", "PRESUPUESTO_LEER"));
        defecto.put("RESPONSABLE_FINANCIERO", List.of("PRESUPUESTO_LEER", "PRESUPUESTO_CREAR", "PRESUPUESTO_EDITAR"));
        defecto.put("TECNICO", List.of("ACTIVOS_LEER", "MANTENIMIENTO_LEER", "MANTENIMIENTO_CREAR", "MANTENIMIENTO_EDITAR"));

        Map<String, Rol> creados = new LinkedHashMap<>();
        Rol admin = rolRepository.save(Rol.builder()
                .empresaId(empresaId).nombre("ADMINISTRADOR").descripcion("Acceso total al sistema")
                .activo(true).esSistema(true).permisos(new java.util.LinkedHashSet<>(todos)).build());
        creados.put("ADMINISTRADOR", admin);

        for (var entrada : defecto.entrySet()) {
            Set<Permiso> permisos = new LinkedHashSet<>();
            for (String clave : entrada.getValue()) {
                int sep = clave.lastIndexOf('_');
                permisoRepository.findByModuloAndAccion(clave.substring(0, sep), clave.substring(sep + 1))
                        .ifPresent(permisos::add);
            }
            Rol rol = rolRepository.save(Rol.builder()
                    .empresaId(empresaId).nombre(entrada.getKey())
                    .descripcion("Rol por defecto de la empresa").activo(true).esSistema(true)
                    .permisos(permisos).build());
            creados.put(entrada.getKey(), rol);
        }
        return creados;
    }
}
