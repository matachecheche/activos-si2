package com.uagrm.activos.repository;

import com.uagrm.activos.model.VerificacionInventario;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VerificacionInventarioRepository extends JpaRepository<VerificacionInventario, Long> {
    Page<VerificacionInventario> findByEmpresaIdOrderByFechaHoraDesc(Long empresaId, Pageable pageable);
    long countByEmpresaIdAndResultado(Long empresaId, String resultado);
}
