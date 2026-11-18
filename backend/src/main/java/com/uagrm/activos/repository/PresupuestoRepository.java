package com.uagrm.activos.repository;

import com.uagrm.activos.model.Area;
import com.uagrm.activos.model.Presupuesto;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PresupuestoRepository extends JpaRepository<Presupuesto, Long> {
    boolean existsByAreaAndGestion(Area area, Integer gestion);

    boolean existsByArea(Area area);

    List<Presupuesto> findAllByOrderByGestionDescIdDesc();
}
