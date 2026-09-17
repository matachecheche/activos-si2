package com.uagrm.activos.repository;

import com.uagrm.activos.model.Activo;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ActivoRepository extends JpaRepository<Activo, Long> {
    boolean existsByCodigo(String codigo);
}
