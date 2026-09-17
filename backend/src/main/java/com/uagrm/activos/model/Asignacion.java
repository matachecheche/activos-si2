package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "asignacion")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Asignacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "activo_id")
    private Activo activo;

    @ManyToOne(optional = false)
    @JoinColumn(name = "responsable_id")
    private Usuario responsable;

    @ManyToOne(optional = false)
    @JoinColumn(name = "ubicacion_id")
    private Ubicacion ubicacion;

    @Column(name = "fecha_asignacion", nullable = false)
    private LocalDateTime fechaAsignacion;

    // HU-03: se conserva historial; solo una asignacion "activa" por activo
    @Builder.Default
    private Boolean activa = true;
}
