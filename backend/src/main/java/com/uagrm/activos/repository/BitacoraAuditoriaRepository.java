package com.uagrm.activos.repository;

import com.uagrm.activos.model.BitacoraAuditoria;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface BitacoraAuditoriaRepository extends JpaRepository<BitacoraAuditoria, Long> {

    Optional<BitacoraAuditoria> findTopByOrderByIdDesc();

    /** La cadena de hashes debe recorrerse SIEMPRE en orden de id, nunca en orden fisico (ctid),
     *  porque inserciones REQUIRES_NEW concurrentes pueden confirmar en orden distinto. */
    List<BitacoraAuditoria> findAllByOrderByIdAsc();

    @Query("select b from BitacoraAuditoria b where " +
           "(:empresaId is null or b.empresaId = :empresaId) and " +
           "(:usuario = '' or lower(b.usuarioNombre) like lower(concat('%', :usuario, '%'))) and " +
           "(:accion = '' or b.accion = :accion) and " +
           "(:entidad = '' or b.entidad = :entidad) and " +
           "(b.fechaHora >= :desde) and (b.fechaHora <= :hasta) " +
           "order by b.id desc")
    Page<BitacoraAuditoria> buscar(@Param("empresaId") Long empresaId,
                                   @Param("usuario") String usuario,
                                   @Param("accion") String accion,
                                   @Param("entidad") String entidad,
                                   @Param("desde") LocalDateTime desde,
                                   @Param("hasta") LocalDateTime hasta,
                                   Pageable pageable);
}
