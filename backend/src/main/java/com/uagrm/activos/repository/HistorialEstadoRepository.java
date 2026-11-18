package com.uagrm.activos.repository;

import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.HistorialEstadoActivo;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface HistorialEstadoRepository extends JpaRepository<HistorialEstadoActivo, Long> {
    List<HistorialEstadoActivo> findByActivoOrderByFechaDescIdDesc(Activo activo);

    boolean existsByActivo(Activo activo);
}
