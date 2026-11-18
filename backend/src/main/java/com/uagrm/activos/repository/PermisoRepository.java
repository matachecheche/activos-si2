package com.uagrm.activos.repository;

import com.uagrm.activos.model.Permiso;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PermisoRepository extends JpaRepository<Permiso, Long> {
    Optional<Permiso> findByModuloAndAccion(String modulo, String accion);
}
