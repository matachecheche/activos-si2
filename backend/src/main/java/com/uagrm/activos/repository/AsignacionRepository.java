package com.uagrm.activos.repository;

import com.uagrm.activos.model.Asignacion;
import com.uagrm.activos.model.Activo;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AsignacionRepository extends JpaRepository<Asignacion, Long> {
    Optional<Asignacion> findByActivoAndActivaTrue(Activo activo);
    List<Asignacion> findByActivoOrderByFechaAsignacionDesc(Activo activo);
}
