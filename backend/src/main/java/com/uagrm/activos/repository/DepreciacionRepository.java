package com.uagrm.activos.repository;

import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.DepreciacionActivo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface DepreciacionRepository extends JpaRepository<DepreciacionActivo, Long> {
    List<DepreciacionActivo> findByActivoOrderByPeriodoAsc(Activo activo);

    Optional<DepreciacionActivo> findFirstByActivoOrderByPeriodoDesc(Activo activo);

    boolean existsByActivo(Activo activo);

    @Query("select d.periodo from DepreciacionActivo d where d.activo = :activo")
    List<String> findPeriodosByActivo(@Param("activo") Activo activo);
}
