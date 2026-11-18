package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** HU-06: historial de cambios de estado con motivo, fecha y usuario responsable. */
@Entity
@Table(name = "historial_estado_activo")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class HistorialEstadoActivo {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "activo_id")
    private Activo activo;

    @Convert(converter = EstadoActivoConverter.class)
    @Column(name = "estado_anterior", length = 30)
    private EstadoActivo estadoAnterior;

    @Convert(converter = EstadoActivoConverter.class)
    @Column(name = "estado_nuevo", nullable = false, length = 30)
    private EstadoActivo estadoNuevo;

    @Column(nullable = false, length = 255)
    private String motivo;

    @ManyToOne
    @JoinColumn(name = "usuario_id")
    private Usuario usuario;

    @Column(nullable = false)
    private LocalDateTime fecha;
}
