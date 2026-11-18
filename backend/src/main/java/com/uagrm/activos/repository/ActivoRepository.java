package com.uagrm.activos.repository;

import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Categoria;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ActivoRepository extends JpaRepository<Activo, Long> {
    boolean existsByCodigo(String codigo);

    Optional<Activo> findByCodigo(String codigo);

    List<Activo> findByCategoria(Categoria categoria);

    boolean existsByCategoria(Categoria categoria);

    long countByEmpresaId(Long empresaId);
}
