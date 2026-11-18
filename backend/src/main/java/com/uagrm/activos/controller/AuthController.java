package com.uagrm.activos.controller;

import com.uagrm.activos.dto.EmpresaSesionDto;
import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.saas.RegistroEmpresaService;
import com.uagrm.activos.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * HU-01: iniciar sesion con correo institucional y contrasena.
 * Sprint 3 / multiempresa: listar las empresas del usuario y cambiar de
 * empresa sin volver a autenticarse.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final RegistroEmpresaService registroEmpresaService;

    public AuthController(AuthService authService, RegistroEmpresaService registroEmpresaService) {
        this.authService = authService;
        this.registroEmpresaService = registroEmpresaService;
    }

    // HU-01: iniciar sesion con correo institucional y contrasena
    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    /** Empresas a las que el usuario tiene acceso (con su rol en cada una). */
    @GetMapping("/mis-empresas")
    public List<EmpresaSesionDto> misEmpresas() {
        return authService.misEmpresas(correoActual());
    }

    /**
     * Cambia de empresa y devuelve un token nuevo con el rol de esa empresa.
     *
     * <p>Ronda 11: se aceptan varias formas de enviar el id (empresaId,
     * empresa o id, en el cuerpo o como parametro) para que ninguna version
     * de la web o del movil se quede sin poder cambiar de empresa.</p>
     */
    @PostMapping("/cambiar-empresa")
    public LoginResponse cambiarEmpresa(@RequestBody(required = false) Map<String, Object> cuerpo,
                                        @RequestParam(name = "empresaId", required = false) Long empresaIdParam) {
        Long empresaId = empresaIdParam;
        if (empresaId == null && cuerpo != null) {
            for (String clave : new String[]{"empresaId", "empresa", "id", "empresa_id"}) {
                Object crudo = cuerpo.get(clave);
                if (crudo != null) {
                    try {
                        empresaId = Long.valueOf(crudo.toString().trim());
                    } catch (NumberFormatException e) {
                        throw new org.springframework.web.server.ResponseStatusException(
                                org.springframework.http.HttpStatus.BAD_REQUEST,
                                "El identificador de la empresa no es valido");
                    }
                    break;
                }
            }
        }
        if (empresaId == null) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "Indique la empresa a la que quiere cambiar");
        }
        return authService.cambiarEmpresa(correoActual(), empresaId);
    }

    /**
     * Sprint 3 / multiempresa: agrega una empresa a la cuenta que ya esta
     * autenticada. No pide contrasena (es la misma persona) y deja al usuario
     * como administrador de la empresa nueva, que aparece de inmediato en el
     * selector de empresa.
     */
    @PostMapping("/agregar-empresa")
    public com.uagrm.activos.dto.RegistroEmpresaResponse agregarEmpresa(
            @RequestBody com.uagrm.activos.dto.RegistroEmpresaRequest request) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.UNAUTHORIZED, "Sesión no válida");
        }
        String nombre = auth.getDetails() instanceof String ? (String) auth.getDetails() : null;
        com.uagrm.activos.dto.RegistroEmpresaResponse respuesta =
                registroEmpresaService.registrarParaCuenta(request, auth.getName(), nombre);
        // Ronda 10: la empresa nueva nace con datos de ejemplo en todas las
        // pantallas (se hace tras confirmar el alta).
        registroEmpresaService.sembrarDatosEjemplo(respuesta.getEmpresaId());
        // Ronda 11: se abre el cobro con el metodo de pago elegido.
        return registroEmpresaService.abrirCobro(respuesta, request);
    }

    private String correoActual() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.UNAUTHORIZED, "Sesión no válida");
        }
        return auth.getName();
    }
}
