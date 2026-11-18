package com.uagrm.activos.repository;

import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.EstadoMantenimiento;
import com.uagrm.activos.model.Mantenimiento;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;

public interface MantenimientoRepository extends JpaRepository<Mantenimiento, Long> {
    List<Mantenimiento> findByActivoOrderByFechaProgramadaDescIdDesc(Activo activo);

    List<Mantenimiento> findByActivoAndEstadoIn(Activo activo, Collection<EstadoMantenimiento> estados);

    boolean existsByActivo(Activo activo);

    boolean existsByActivoAndEstado(Activo activo, EstadoMantenimiento estado);

    List<Mantenimiento> findByEstadoAndFechaProgramadaBetweenOrderByFechaProgramadaAsc(
            EstadoMantenimiento estado, LocalDate desde, LocalDate hasta);

    List<Mantenimiento> findByEstadoAndFechaProgramadaLessThanOrderByFechaProgramadaAsc(
            EstadoMantenimiento estado, LocalDate fecha);

    List<Mantenimiento> findAllByOrderByFechaProgramadaDescIdDesc();
}
