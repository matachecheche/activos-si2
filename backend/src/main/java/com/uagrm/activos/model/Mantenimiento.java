package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/** HU-08: mantenimientos preventivos (programados) y correctivos. */
@Entity
@Table(name = "mantenimiento")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Mantenimiento {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "activo_id")
    private Activo activo;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TipoMantenimiento tipo;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private EstadoMantenimiento estado = EstadoMantenimiento.PROGRAMADO;

    @Column(length = 500)
    private String descripcion; // descripcion de la falla (correctivo) o del trabajo (preventivo)

    @Column(name = "fecha_programada")
    private LocalDate fechaProgramada;

    @Column(name = "periodicidad_dias")
    private Integer periodicidadDias; // opcional (preventivos)

    @Column(name = "fecha_inicio")
    private LocalDateTime fechaInicio;

    @Column(name = "fecha_realizada")
    private LocalDate fechaRealizada;

    @Column(precision = 14, scale = 2)
    private BigDecimal costo;

    @Column(length = 150)
    private String tecnico;

    @Column(length = 500)
    private String observaciones;

    // Estado del activo antes de iniciar el mantenimiento (se restaura al finalizar)
    @Convert(converter = EstadoActivoConverter.class)
    @Column(name = "estado_previo_activo", length = 30)
    private EstadoActivo estadoPrevioActivo;

    @Column(name = "fecha_creacion")
    private LocalDateTime fechaCreacion;

    @ManyToOne
    @JoinColumn(name = "creado_por_id")
    private Usuario creadoPor;
}
