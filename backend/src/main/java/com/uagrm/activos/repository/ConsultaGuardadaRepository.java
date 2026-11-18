package com.uagrm.activos.repository;

import com.uagrm.activos.model.ConsultaGuardada;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ConsultaGuardadaRepository extends JpaRepository<ConsultaGuardada, Long> {
    List<ConsultaGuardada> findByEmpresaIdOrderByFechaDesc(Long empresaId);
}
