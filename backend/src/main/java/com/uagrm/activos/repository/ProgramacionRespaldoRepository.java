package com.uagrm.activos.repository;

import com.uagrm.activos.model.ProgramacionRespaldo;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface ProgramacionRespaldoRepository extends JpaRepository<ProgramacionRespaldo, Long> {
    Optional<ProgramacionRespaldo> findByEmpresaId(Long empresaId);
    List<ProgramacionRespaldo> findByActivaTrue();
}
