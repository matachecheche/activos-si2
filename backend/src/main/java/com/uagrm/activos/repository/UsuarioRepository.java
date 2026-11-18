package com.uagrm.activos.repository;

import com.uagrm.activos.model.Rol;
import com.uagrm.activos.model.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UsuarioRepository extends JpaRepository<Usuario, Long> {
    /**
     * Sprint 3 / multiempresa: el correo ya no es unico global, asi que se
     * devuelven todas las membresias (una por empresa). Con el filtro de
     * empresa activo, el resultado es la membresia de la empresa actual.
     */
    List<Usuario> findByCorreo(String correo);

    /** Membresias de una cuenta global (puede estar en varias empresas). */
    List<Usuario> findByCuentaId(Long cuentaId);

    List<Usuario> findByRol(Rol rol);

    long countByEmpresaId(Long empresaId);

    List<Usuario> findByEmpresaId(Long empresaId);
}
