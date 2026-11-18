package com.uagrm.activos.repository;

import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.EjecucionPresupuestaria;
import com.uagrm.activos.model.PartidaPresupuestaria;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EjecucionRepository extends JpaRepository<EjecucionPresupuestaria, Long> {
    List<EjecucionPresupuestaria> findByPartidaOrderByFechaDescIdDesc(PartidaPresupuestaria partida);

    List<EjecucionPresupuestaria> findByPartida_Presupuesto_IdOrderByFechaDescIdDesc(Long presupuestoId);

    boolean existsByPartida(PartidaPresupuestaria partida);

    boolean existsByActivo(Activo activo);
}
