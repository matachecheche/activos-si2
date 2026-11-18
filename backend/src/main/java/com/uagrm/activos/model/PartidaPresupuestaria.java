package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "partida_presupuestaria",
        uniqueConstraints = @UniqueConstraint(name = "uk_partida_presupuesto_codigo", columnNames = {"presupuesto_id", "codigo"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PartidaPresupuestaria {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "presupuesto_id")
    private Presupuesto presupuesto;

    @Column(nullable = false, length = 30)
    private String codigo;

    @Column(nullable = false, length = 150)
    private String nombre;

    @Column(name = "monto_planificado", nullable = false, precision = 14, scale = 2)
    private BigDecimal montoPlanificado;
}
