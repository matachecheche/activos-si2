package com.uagrm.activos.service;

import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Datos del usuario autenticado en la peticion actual (el token JWT lleva rol y permisos). */
@Service
public class SesionService {

    private final UsuarioRepository usuarioRepository;

    public SesionService(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    public Usuario usuarioActual() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión no válida");
        }
        // La membresia exacta con la que se emitio el token (multiempresa);
        // si no viene en el token se resuelve por correo dentro de la empresa.
        Long usuarioId = TenantContext.getUsuarioId();
        if (usuarioId != null) {
            var porId = usuarioRepository.findById(usuarioId);
            if (porId.isPresent()) {
                return porId.get();
            }
        }
        return usuarioRepository.findByCorreo(auth.getName()).stream().findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión no válida"));
    }

    public boolean esAdministrador() {
        return tieneAutoridad("ROLE_ADMINISTRADOR");
    }

    /** Permiso con el formato MODULO_ACCION, por ejemplo ACTIVOS_ELIMINAR. */
    public boolean tienePermiso(String permiso) {
        return esAdministrador() || tieneAutoridad("PERM_" + permiso);
    }

    private boolean tieneAutoridad(String autoridad) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) {
            return false;
        }
        for (GrantedAuthority a : auth.getAuthorities()) {
            if (autoridad.equals(a.getAuthority())) {
                return true;
            }
        }
        return false;
    }
}
