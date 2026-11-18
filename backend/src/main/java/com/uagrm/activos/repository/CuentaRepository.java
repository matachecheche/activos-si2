package com.uagrm.activos.repository;

import com.uagrm.activos.model.Cuenta;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/**
 * Sprint 3 / multiempresa: repositorio de la identidad global.
 * No lleva filtro de tenant a proposito (la tabla `cuenta` es global).
 */
public interface CuentaRepository extends JpaRepository<Cuenta, Long> {

    Optional<Cuenta> findByCorreo(String correo);

    boolean existsByCorreo(String correo);
}
