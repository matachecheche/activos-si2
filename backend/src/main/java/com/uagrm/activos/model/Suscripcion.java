package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

/** HU-11: una suscripcion vigente por empresa. */
@Entity
@Table(name = "suscripcion")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Suscripcion {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(optional = false)
    @JoinColumn(name = "empresa_id", nullable = false)
    private Empresa empresa;
    @ManyToOne(optional = false)
    @JoinColumn(name = "plan_id", nullable = false)
    private Plan plan;
    @Column(name = "fecha_inicio", nullable = false)
    @Builder.Default
    private LocalDateTime fechaInicio = LocalDateTime.now();
    @Column(name = "fecha_vencimiento", nullable = false)
    private LocalDateTime fechaVencimiento;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private EstadoSuscripcion estado = EstadoSuscripcion.ACTIVA;
    @Column(name = "fecha_estado", nullable = false)
    @Builder.Default
    private LocalDateTime fechaEstado = LocalDateTime.now();
}
