package com.uagrm.activos.saas;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.model.Cuenta;
import com.uagrm.activos.model.Empresa;
import com.uagrm.activos.model.Permiso;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.CuentaRepository;
import com.uagrm.activos.repository.EmpresaRepository;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.repository.SuscripcionRepository;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.security.JwtUtil;
import com.uagrm.activos.tenant.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * HU-12: el Super Admin de la plataforma puede entrar a cualquier empresa para
 * trabajar con sus datos (web y movil). Estos tests cubren ese escenario.
 */
class EmpresaAdminServiceTest {

    private EmpresaRepository empresaRepository;
    private SuscripcionRepository suscripcionRepository;
    private CuentaRepository cuentaRepository;
    private PermisoRepository permisoRepository;
    private JwtUtil jwtUtil;
    private AuditoriaService auditoriaService;
    private JdbcTemplate jdbc;
    private EmpresaAdminService servicio;

    @BeforeEach
    void setUp() {
        empresaRepository = mock(EmpresaRepository.class);
        suscripcionRepository = mock(SuscripcionRepository.class);
        cuentaRepository = mock(CuentaRepository.class);
        permisoRepository = mock(PermisoRepository.class);
        jwtUtil = mock(JwtUtil.class);
        auditoriaService = mock(AuditoriaService.class);
        jdbc = mock(JdbcTemplate.class);
        servicio = new EmpresaAdminService(
                empresaRepository,
                suscripcionRepository,
                mock(UsuarioRepository.class),
                mock(ActivoRepository.class),
                auditoriaService,
                cuentaRepository,
                permisoRepository,
                jwtUtil,
                jdbc);
        TenantContext.limpiar();
        TenantContext.setNivel(TenantContext.NIVEL_SUPER_ADMIN);
        TenantContext.setCorreo("superadmin@plataforma.local");
    }

    @AfterEach
    void tearDown() {
        TenantContext.limpiar();
    }

    private Empresa empresa(Long id, String nombre) {
        return Empresa.builder().id(id).nombre(nombre).nit("NIT-" + id).build();
    }

    @Test
    void elSuperAdminEntraAUnaEmpresaYRecibeSesionConSuContexto() {
        when(empresaRepository.findAll()).thenReturn(List.of(empresa(1L, "Demo"), empresa(2L, "Sede Norte")));
        when(empresaRepository.findById(2L)).thenReturn(Optional.of(empresa(2L, "Sede Norte")));
        when(cuentaRepository.findByCorreo("superadmin@plataforma.local"))
                .thenReturn(Optional.of(Cuenta.builder().id(1L).correo("superadmin@plataforma.local")
                        .nombre("Super Administrador").nivel("SUPER_ADMIN").build()));
        when(permisoRepository.findAll()).thenReturn(List.of(
                Permiso.builder().id(1L).modulo("ACTIVOS").accion("LEER").build(),
                Permiso.builder().id(2L).modulo("ACTIVOS").accion("EDITAR").build()));
        when(jwtUtil.generarToken(anyString(), anyString(), anyCollection(), anyLong(), anyString(), any()))
                .thenReturn("TOKEN-SUPER");
        // Los conteos del detalle se hacen con SQL directo (el filtro de
        // empresa de Hibernate devolveria 0 para el Super Admin).
        when(jdbc.queryForObject(anyString(), eq(Long.class), any())).thenReturn(7L);

        LoginResponse res = servicio.entrarComoEmpresa(2L);

        assertNotNull(res);
        assertEquals("TOKEN-SUPER", res.getToken());
        assertEquals(2L, res.getEmpresaId());
        assertEquals("Sede Norte", res.getEmpresaNombre());
        assertEquals("SUPER_ADMIN", res.getRol());
        assertEquals("SUPER_ADMIN", res.getNivel());
        assertTrue(res.getPermisos().contains("ACTIVOS_LEER"));
        // El selector de empresas debe listar todas las empresas del SaaS.
        assertEquals(2, res.getEmpresas().size());
        assertTrue(res.getEmpresas().stream().anyMatch(e -> Boolean.TRUE.equals(e.getActual())));
        // La entrada queda registrada en la bitacora.
        verify(auditoriaService).registrar(eq("ENTRAR_EMPRESA"), eq("EMPRESA"), eq("2"), anyString());
    }

    @Test
    void elDetalleDeLaEmpresaMuestraLosConteosReales() {
        when(empresaRepository.findById(1L)).thenReturn(Optional.of(empresa(1L, "Demo")));
        when(suscripcionRepository.findByEmpresaId(1L)).thenReturn(Optional.empty());
        when(jdbc.queryForObject(anyString(), eq(Long.class), any())).thenReturn(12L);

        java.util.Map<String, Object> vista = servicio.detalleEmpresa(1L);

        assertEquals(12L, vista.get("usuarios"));
        assertEquals(12L, vista.get("activos"));
        assertEquals(12L, vista.get("presupuestos"));
    }

    @Test
    void unUsuarioNormalNoPuedeEntrarAUnaEmpresa() {
        TenantContext.setNivel(TenantContext.NIVEL_REGULAR);
        assertThrows(ResponseStatusException.class, () -> servicio.entrarComoEmpresa(1L));
        verify(empresaRepository, never()).findById(anyLong());
    }

    @Test
    void noSePuedeEntrarALaEmpresaDePlataforma() {
        assertThrows(ResponseStatusException.class, () -> servicio.entrarComoEmpresa(0L));
    }
}
