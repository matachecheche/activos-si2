package com.uagrm.activos.repository;

import com.uagrm.activos.model.ConfiguracionEmpresa;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface ConfiguracionEmpresaRepository extends JpaRepository<ConfiguracionEmpresa, Long> {
    Optional<ConfiguracionEmpresa> findByEmpresaId(Long empresaId);
}
