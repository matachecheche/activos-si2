package com.uagrm.activos;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.model.Cuenta;
import com.uagrm.activos.model.Empresa;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.pagos.ProveedorPagos;
import com.uagrm.activos.pagos.TransferenciaProveedor;
import com.uagrm.activos.repository.CuentaRepository;
import com.uagrm.activos.repository.EmpresaRepository;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.security.JwtUtil;
import com.uagrm.activos.service.AuthService;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.TypedQuery;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Ronda 11: cambio de empresa sin mensajes genericos, Super Admin en el
 * selector de empresa y transferencia bancaria como metodo de pago real.
 */
class Ronda11Test {

    // ------------------------------------------------------ transferencia

    @Test
    void transferenciaSinDatosBancariosNoEstaConfigurada() {
        TransferenciaProveedor proveedor = new TransferenciaProveedor("", "", "", "", "", "BOB", "");
        assertFalse(proveedor.configurado());
        assertEquals("TRANSFERENCIA", proveedor.nombre());
        assertEquals("BOB", proveedor.moneda());
    }

    @Test
    void transferenciaCreaLaOrdenConLosDatosDeLaCuenta() {
        TransferenciaProveedor proveedor =
                new TransferenciaProveedor("Banco Nacional", "0001-12345678", "Activos Fijos Srl",
                        "102030405", "Central", "BOB", "Transfiere el monto exacto.");
        assertTrue(proveedor.configurado());

        ProveedorPagos.SolicitudCheckout solicitud = new ProveedorPagos.SolicitudCheckout(
                "PAG-123", "Suscripcion Basico", "Activos Fijos", new BigDecimal("150.00"),
                "admin@uagrm.edu.bo", "BOB", "https://app/suscripcion?pago=PAG-123",
                "https://app/suscripcion?pago=PAG-123&estado=fallido",
                "https://app/suscripcion?pago=PAG-123&estado=pendiente",
                "https://app/api/pagos/webhook");

        ProveedorPagos.CheckoutPago checkout = proveedor.crearCheckout(solicitud);
        assertEquals("PAG-123", checkout.checkoutId());
        assertEquals("PENDIENTE", checkout.estado());
        assertNotNull(checkout.datosBancarios());
        assertEquals("Banco Nacional", checkout.datosBancarios().get("banco"));
        assertEquals("0001-12345678", checkout.datosBancarios().get("cuenta"));
        assertEquals("Activos Fijos Srl", checkout.datosBancarios().get("titular"));
        // La transferencia no se aprueba sola: la confirma un administrador.
        ProveedorPagos.ResultadoPago resultado = proveedor.confirmarNotificacion("{}", Map.of());
        assertFalse(resultado.aprobado());
        assertNotNull(resultado.mensaje());
    }

    // ------------------------------------------------------ cambio de empresa

    private UsuarioRepository usuarioRepository;
    private CuentaRepository cuentaRepository;
    private EntityManagerFactory entityManagerFactory;
    private EntityManager entityManager;
    private TypedQuery<Usuario> query;
    private PermisoRepository permisoRepository;
    private AuditoriaService auditoriaService;
    private EmpresaRepository empresaRepository;
    private JwtUtil jwtUtil;
    private PasswordEncoder passwordEncoder;
    private AuthService authService;

    @BeforeEach
    void preparar() {
        usuarioRepository = mock(UsuarioRepository.class);
        cuentaRepository = mock(CuentaRepository.class);
        entityManagerFactory = mock(EntityManagerFactory.class);
        entityManager = mock(EntityManager.class);
        query = mock(TypedQuery.class);
        permisoRepository = mock(PermisoRepository.class);
        auditoriaService = mock(AuditoriaService.class);
        empresaRepository = mock(EmpresaRepository.class);
        jwtUtil = mock(JwtUtil.class);
        passwordEncoder = mock(PasswordEncoder.class);

        when(entityManagerFactory.createEntityManager()).thenReturn(entityManager);
        when(entityManager.createQuery(anyString(), eq(Usuario.class))).thenReturn(query);
        when(query.setParameter(anyString(), any())).thenReturn(query);

        authService = new AuthService(usuarioRepository, cuentaRepository, entityManagerFactory,
                passwordEncoder, jwtUtil, permisoRepository, auditoriaService, empresaRepository);
    }

    @AfterEach
    void limpiar() {
        com.uagrm.activos.tenant.TenantContext.limpiar();
    }

    private Cuenta cuenta(String correo, String nivel) {
        Cuenta c = new Cuenta();
        c.setId(1L);
        c.setCorreo(correo);
        c.setNombre("Persona");
        c.setNivel(nivel);
        c.setActivo(true);
        return c;
    }

    private Usuario membresia(Long empresaId, String rol, boolean activa) {
        Rol r = new Rol();
        r.setId(1L);
        r.setNombre(rol);
        r.setEmpresaId(empresaId);
        r.setActivo(true);
        Usuario u = new Usuario();
        u.setId(10L + empresaId);
        u.setEmpresaId(empresaId);
        u.setCorreo("admin@uagrm.edu.bo");
        u.setCuentaId(1L);
        u.setRol(r);
        u.setActivo(activa);
        return u;
    }

    @Test
    void administradorCambiaAUnaEmpresaDondeEsMiembro() {
        Cuenta cuenta = cuenta("admin@uagrm.edu.bo", "ADMIN");
        when(cuentaRepository.findByCorreo("admin@uagrm.edu.bo")).thenReturn(Optional.of(cuenta));
        when(query.getResultList()).thenReturn(List.of(membresia(1L, "ADMINISTRADOR", true),
                membresia(2L, "ADMINISTRADOR", true)));
        when(empresaRepository.findById(2L)).thenReturn(Optional.of(
                Empresa.builder().id(2L).nombre("Sede Norte").build()));
        when(jwtUtil.generarToken(anyString(), anyString(), any(), anyLong(), anyString(), any()))
                .thenReturn("token-nuevo");

        LoginResponse respuesta = authService.cambiarEmpresa("admin@uagrm.edu.bo", 2L);

        assertNotNull(respuesta);
        assertEquals("token-nuevo", respuesta.getToken());
        assertEquals(2L, respuesta.getEmpresaId());
        assertEquals("Sede Norte", respuesta.getEmpresaNombre());
    }

    @Test
    void sinMembresiaElErrorExplicaElMotivo() {
        Cuenta cuenta = cuenta("nuevo@uagrm.edu.bo", "REGULAR");
        when(cuentaRepository.findByCorreo("nuevo@uagrm.edu.bo")).thenReturn(Optional.of(cuenta));
        when(query.getResultList()).thenReturn(List.of());
        when(empresaRepository.findById(9L)).thenReturn(Optional.of(
                Empresa.builder().id(9L).nombre("Empresa Ajena").build()));

        ResponseStatusException error = assertThrows(ResponseStatusException.class,
                () -> authService.cambiarEmpresa("nuevo@uagrm.edu.bo", 9L));
        assertEquals(403, error.getStatusCode().value());
        assertTrue(error.getReason().contains("Empresa Ajena"),
                "El mensaje debe decir a que empresa no hay acceso: " + error.getReason());
    }

    @Test
    void superAdminEntraALaEmpresaDesdeElSelector() {
        Cuenta cuenta = cuenta("superadmin@plataforma.local", "SUPER_ADMIN");
        when(cuentaRepository.findByCorreo("superadmin@plataforma.local"))
                .thenReturn(Optional.of(cuenta));
        // El Super Admin no es miembro de las empresas cliente.
        when(query.getResultList()).thenReturn(List.of(membresia(0L, "SUPER_ADMIN", true)));
        when(empresaRepository.findById(3L)).thenReturn(Optional.of(
                Empresa.builder().id(3L).nombre("Cliente SpA").build()));
        when(empresaRepository.findAll()).thenReturn(List.of(
                Empresa.builder().id(0L).nombre("Plataforma").build(),
                Empresa.builder().id(3L).nombre("Cliente SpA").build()));
        when(jwtUtil.generarToken(anyString(), anyString(), any(), anyLong(), anyString(), any()))
                .thenReturn("token-superadmin");

        LoginResponse respuesta = authService.cambiarEmpresa("superadmin@plataforma.local", 3L);

        assertNotNull(respuesta);
        assertEquals("token-superadmin", respuesta.getToken());
        assertEquals(3L, respuesta.getEmpresaId());
        assertEquals("SUPER_ADMIN", respuesta.getRol());
    }

    @Test
    void empresaInexistenteDaUnErrorClaro() {
        Cuenta cuenta = cuenta("admin@uagrm.edu.bo", "ADMIN");
        when(cuentaRepository.findByCorreo("admin@uagrm.edu.bo")).thenReturn(Optional.of(cuenta));
        when(query.getResultList()).thenReturn(List.of(membresia(1L, "ADMINISTRADOR", true)));
        when(empresaRepository.findById(77L)).thenReturn(Optional.empty());

        ResponseStatusException error = assertThrows(ResponseStatusException.class,
                () -> authService.cambiarEmpresa("admin@uagrm.edu.bo", 77L));
        assertEquals(404, error.getStatusCode().value());
        assertTrue(error.getReason().toLowerCase().contains("no existe"));
    }
}
