package com.uagrm.activos.repository;

import com.uagrm.activos.model.Respaldo;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface RespaldoRepository extends JpaRepository<Respaldo, Long> {
    List<Respaldo> findByEmpresaIdOrderByFechaDesc(Long empresaId);
    List<Respaldo> findAllByOrderByFechaDesc();
    long countByEmpresaIdAndTipo(Long empresaId, String tipo);
}
