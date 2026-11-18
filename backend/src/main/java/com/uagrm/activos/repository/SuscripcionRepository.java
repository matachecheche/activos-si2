package com.uagrm.activos.repository;

import com.uagrm.activos.model.Suscripcion;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface SuscripcionRepository extends JpaRepository<Suscripcion, Long> {
    Optional<Suscripcion> findByEmpresaId(Long empresaId);
}
