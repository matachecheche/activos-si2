package com.uagrm.activos.repository;

import com.uagrm.activos.model.Empresa;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface EmpresaRepository extends JpaRepository<Empresa, Long> {
    Optional<Empresa> findByNit(String nit);
    boolean existsByNit(String nit);
}
