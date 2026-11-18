package com.uagrm.activos.repository;

import com.uagrm.activos.model.PartidaPresupuestaria;
import com.uagrm.activos.model.Presupuesto;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PartidaRepository extends JpaRepository<PartidaPresupuestaria, Long> {
    List<PartidaPresupuestaria> findByPresupuestoOrderByCodigoAsc(Presupuesto presupuesto);

    boolean existsByPresupuestoAndCodigoIgnoreCase(Presupuesto presupuesto, String codigo);

    /** Bloquea la fila de la partida para que dos operaciones simultaneas no superen el saldo. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PartidaPresupuestaria p where p.id = :id")
    Optional<PartidaPresupuestaria> findByIdForUpdate(@Param("id") Long id);
}
