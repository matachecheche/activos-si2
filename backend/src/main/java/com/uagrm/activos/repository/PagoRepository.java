package com.uagrm.activos.repository;

import com.uagrm.activos.model.Pago;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface PagoRepository extends JpaRepository<Pago, Long> {
    List<Pago> findBySuscripcionEmpresaIdOrderByFechaDesc(Long empresaId);
    List<Pago> findAllByOrderByFechaDesc();

    /** Pago por su referencia interna (la que viaja en la notificacion). */
    Optional<Pago> findByReferencia(String referencia);

    /** Pago por el identificador del checkout en la pasarela. */
    Optional<Pago> findByCheckoutId(String checkoutId);
}
