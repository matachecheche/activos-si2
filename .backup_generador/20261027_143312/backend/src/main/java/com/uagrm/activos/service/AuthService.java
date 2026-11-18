package com.uagrm.activos.service;

import com.uagrm.activos.dto.EmpresaSesionDto;
import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.model.Cuenta;
import com.uagrm.activos.model.Empresa;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.CuentaRepository;
import com.uagrm.activos.repository.EmpresaRepository;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.security.JwtUtil;
import com.uagrm.activos.tenant.TenantContext;
import com.uagrm.activos.auditoria.AuditoriaService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

// HU-01: Iniciar sesion en el sistema
/**
 * Sprint 3 / multiempresa: la identidad es global (tabla `cuenta`) y cada
 * fila de `usuario` es la membresía de esa persona en una empresa, con su rol.
 * Un login puede ver varias empresas y cambiar entre ellas.
 */
@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final CuentaRepository cuentaRepository;
    private final EntityManagerFactory entityManagerFactory;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final PermisoRepository permisoRepository;
    private final AuditoriaService auditoriaService;
    private final EmpresaRepository empresaRepository;

    @Value("${app.jwt.max-intentos-fallidos}")
    private int maxIntentos;

    @Value("${app.jwt.segundos-bloqueo}")
    private int segundosBloqueo;

    public AuthService(UsuarioRepository usuarioRepository, CuentaRepository cuentaRepository,
                       EntityManagerFactory entityManagerFactory,
                       PasswordEncoder passwordEncoder, JwtUtil jwtUtil,
                       PermisoRepository permisoRepository, AuditoriaService auditoriaService,
                       EmpresaRepository empresaRepository) {
        this.usuarioRepository = usuarioRepository;
        this.cuentaRepository = cuentaRepository;
        this.entityManagerFactory = entityManagerFactory;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.permisoRepository = permisoRepository;
        this.auditoriaService = auditoriaService;
        this.empresaRepository = empresaRepository;
    }

    public LoginResponse login(LoginRequest request) {
        String correo = request.getCorreo().trim().toLowerCase();
        Cuenta cuenta = cuentaRepository.findByCorreo(correo).orElse(null);
        if (cuenta == null) {
            // Respaldo: usuarios creados antes de la tabla `cuenta` (por ejemplo
            // con un INSERT manual en la base). Se migran a una cuenta global.
            cuenta = crearCuentaDesdeUsuario(correo);
            if (cuenta == null) {
                throw new BadCredentialsException("Credenciales inválidas");
            }
        }

        if (!Boolean.TRUE.equals(cuenta.getActivo())) {
            throw new BadCredentialsException("La cuenta no está activa");
        }

        if (cuenta.getBloqueadoHasta() != null && cuenta.getBloqueadoHasta().isAfter(LocalDateTime.now())) {
            long segundosRestantes = Math.max(1, java.time.Duration.between(LocalDateTime.now(), cuenta.getBloqueadoHasta()).getSeconds());
            throw new ResponseStatusException(HttpStatus.LOCKED, "Cuenta bloqueada. Intenta nuevamente en " + segundosRestantes + " segundos.");
        }

        if (cuenta.getBloqueadoHasta() != null) {
            cuenta.setBloqueadoHasta(null);
            cuenta.setIntentosFallidos(0);
        }

        if (!passwordEncoder.matches(request.getPassword(), cuenta.getPassword())) {
            cuenta.setIntentosFallidos(cuenta.getIntentosFallidos() + 1);
            if (cuenta.getIntentosFallidos() >= maxIntentos) {
                cuenta.setBloqueadoHasta(LocalDateTime.now().plusSeconds(segundosBloqueo));
                cuentaRepository.save(cuenta);
                auditoriaService.registrar("BLOQUEO", "USUARIO", String.valueOf(cuenta.getId()),
                        "Cuenta bloqueada " + segundosBloqueo + " s por intentos fallidos");
                throw new ResponseStatusException(HttpStatus.LOCKED, "Cuenta bloqueada durante " + segundosBloqueo + " segundos por superar el límite de intentos.");
            }
            cuentaRepository.save(cuenta);
            throw new BadCredentialsException("Credenciales inválidas");
        }

        cuenta.setIntentosFallidos(0);
        cuenta.setBloqueadoHasta(null);
        cuentaRepository.save(cuenta);

        // Membresía principal: la primera empresa activa de la persona.
        List<Usuario> membresias = membresiasDe(cuenta);
        if (membresias.isEmpty()) {
            throw new BadCredentialsException("La cuenta no tiene acceso a ninguna empresa");
        }
        Usuario membresia = membresias.get(0);
        if (membresia.getRol() == null || !membresia.getRol().estaActivo()) {
            throw new BadCredentialsException("El rol de la cuenta está inactivo");
        }

        auditoriaService.registrar("LOGIN", "USUARIO", String.valueOf(membresia.getId()),
                "Inicio de sesion exitoso de " + cuenta.getCorreo());
        return respuesta(cuenta, membresia);
    }

    /** Empresas a las que tiene acceso la persona, con su rol y permisos. */
    @Transactional(readOnly = true)
    public List<EmpresaSesionDto> misEmpresas(String correo) {
        Cuenta cuenta = cuentaRepository.findByCorreo(correo.trim().toLowerCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión no válida"));
        return listaEmpresas(cuenta, actualEmpresaId(cuenta));
    }

    /**
     * Cambio de empresa: valida la membresía y emite un token nuevo con el
     * rol y los permisos de esa empresa. No hace falta volver a autenticarse.
     */
    @Transactional
    public LoginResponse cambiarEmpresa(String correo, Long empresaId) {
        Cuenta cuenta = cuentaRepository.findByCorreo(correo.trim().toLowerCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión no válida"));
        if (empresaId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indique la empresa a la que quiere cambiar");
        }
        Usuario membresia = membresiasDe(cuenta).stream()
                .filter(u -> empresaId.equals(u.getEmpresaId()))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "No tiene acceso a la empresa solicitada"));
        if (membresia.getRol() == null || !membresia.getRol().estaActivo()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "El rol en esa empresa está inactivo");
        }
        auditoriaService.registrar("CAMBIO_EMPRESA", "USUARIO", String.valueOf(membresia.getId()),
                "Cambio a empresa " + empresaId);
        return respuesta(cuenta, membresia);
    }

    // ------------------------------------------------------------------ apoyo

    private LoginResponse respuesta(Cuenta cuenta, Usuario membresia) {
        List<String> permisos = permisosDe(membresia);
        String nivel = cuenta.getNivel() != null ? cuenta.getNivel() : "REGULAR";
        String rol = membresia.getRol() == null ? "REGULAR" : membresia.getRol().getNombre();
        Long empresaId = membresia.getEmpresaId();
        String token = jwtUtil.generarToken(cuenta.getCorreo(), rol, permisos, empresaId, nivel,
                membresia.getId());
        String empresaNombre = empresaId == null ? null
                : empresaRepository.findById(empresaId).map(Empresa::getNombre).orElse(null);
        return LoginResponse.builder()
                .token(token)
                .nombre(cuenta.getNombre())
                .rol(rol)
                .permisos(permisos)
                .empresaId(empresaId)
                .nivel(nivel)
                .empresaNombre(empresaNombre)
                .empresas(listaEmpresas(cuenta, empresaId))
                .build();
    }

    /**
     * Membresías (filas de usuario) de la persona, en cualquier empresa.
     *
     * Se carga con el contexto de empresa en blanco: la tabla `usuario` esta
     * particionada por empresa_id y el filtro de Hibernate solo devolveria
     * los usuarios de la empresa actual, que es justo lo que se quiere listar.
     * El contexto se restaura al terminar para que la auditoria siga viendo
     * la empresa de la peticion.
     */
    /**
     * Crea la cuenta global a partir de un usuario heredado del Sprint 2
     * (que no tendria fila en `cuenta`). Conserva el hash de contrasena.
     */
    private Cuenta crearCuentaDesdeUsuario(String correo) {
        List<Usuario> usuarios = usuarioRepository.findByCorreo(correo);
        if (usuarios.isEmpty()) {
            return null;
        }
        Usuario origen = usuarios.get(0);
        Cuenta cuenta = new Cuenta();
        cuenta.setCorreo(correo);
        cuenta.setNombre(origen.getNombre());
        cuenta.setPassword(origen.getPassword());
        String nivel = origen.getNivel();
        cuenta.setNivel(("SUPER_ADMIN".equalsIgnoreCase(nivel) || "ADMIN".equalsIgnoreCase(nivel))
                ? nivel.toUpperCase() : "REGULAR");
        cuenta.setIntentosFallidos(origen.getIntentosFallidos() == null ? 0 : origen.getIntentosFallidos());
        cuenta.setBloqueadoHasta(origen.getBloqueadoHasta());
        cuenta.setActivo(!Boolean.FALSE.equals(origen.getActivo()));
        return cuentaRepository.save(cuenta);
    }

    private List<Usuario> membresiasDe(Cuenta cuenta) {
        Long empresaOriginal = TenantContext.getEmpresaId();
        List<Usuario> todas;
        try {
            // Sesion propia sin filtro de empresa: la tabla `usuario` esta
            // particionada por empresa_id y Hibernate resolveria el tenant de
            // la peticion, dejando fuera las membresias de las demas empresas
            // (y sus roles, que tampoco se podrian cargar).
            TenantContext.setEmpresaId(null);
            EntityManager em = entityManagerFactory.createEntityManager();
            try {
                todas = em.createQuery(
                                "select u from Usuario u where u.cuentaId = :cid order by u.empresaId",
                                Usuario.class)
                        .setParameter("cid", cuenta.getId())
                        .getResultList();
                if (todas.isEmpty()) {
                    // Respaldo: cuentas creadas antes de la migracion (cuenta_id
                    // nulo) se resuelven por correo, de modo que ningun usuario
                    // se queda fuera.
                    todas = em.createQuery(
                                    "select u from Usuario u where u.correo = :correo order by u.empresaId",
                                    Usuario.class)
                            .setParameter("correo", cuenta.getCorreo())
                            .getResultList();
                }
            } finally {
                em.close();
            }
        } finally {
            TenantContext.setEmpresaId(empresaOriginal);
        }
        return todas.stream()
                .filter(u -> Boolean.TRUE.equals(u.getActivo()))
                .filter(u -> u.getRol() == null || u.getRol().estaActivo())
                .sorted(Comparator.comparing(Usuario::getEmpresaId,
                        Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();
    }

    /** Empresa actual segun el token: la del contexto de la peticion. */
    private Long actualEmpresaId(Cuenta cuenta) {
        Long delContexto = TenantContext.getEmpresaId();
        if (delContexto != null) {
            return delContexto;
        }
        return membresiasDe(cuenta).stream()
                .map(Usuario::getEmpresaId).filter(java.util.Objects::nonNull).findFirst().orElse(null);
    }

    /** Lista de empresas de la persona, con la actual marcada. */
    private List<EmpresaSesionDto> listaEmpresas(Cuenta cuenta, Long actual) {
        List<EmpresaSesionDto> lista = new ArrayList<>();
        for (Usuario membresia : membresiasDe(cuenta)) {
            Empresa empresa = membresia.getEmpresaId() == null ? null
                    : empresaRepository.findById(membresia.getEmpresaId()).orElse(null);
            lista.add(EmpresaSesionDto.builder()
                    .empresaId(membresia.getEmpresaId())
                    .empresaNombre(empresa == null ? "Sin empresa" : empresa.getNombre())
                    .nit(empresa == null ? null : empresa.getNit())
                    .rol(membresia.getRol() == null ? null : membresia.getRol().getNombre())
                    .permisos(permisosDe(membresia))
                    .actual(membresia.getEmpresaId() != null && membresia.getEmpresaId().equals(actual))
                    .build());
        }
        return lista;
    }

    /** Permisos del rol de la membresia; el ADMINISTRADOR los tiene todos. */
    private List<String> permisosDe(Usuario membresia) {
        if (membresia.getRol() == null) {
            return List.of();
        }
        if ("ADMINISTRADOR".equalsIgnoreCase(membresia.getRol().getNombre())) {
            return permisoRepository.findAll().stream().map(p -> p.getModulo() + "_" + p.getAccion()).toList();
        }
        return membresia.getRol().getPermisos().stream().map(p -> p.getModulo() + "_" + p.getAccion()).toList();
    }
}
