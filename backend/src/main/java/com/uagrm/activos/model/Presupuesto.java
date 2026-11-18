package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** HU-09: presupuesto anual por gestion y area (un area solo tiene uno por gestion). */
@Entity
@Table(name = "presupuesto",
        uniqueConstraints = @UniqueConstraint(name = "uk_presupuesto_area_gestion", columnNames = {"area_id", "gestion"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Presupuesto {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "area_id")
    private Area area;

    @Column(nullable = false)
    private Integer gestion;

    @Column(name = "monto_aprobado", nullable = false, precision = 14, scale = 2)
    private BigDecimal montoAprobado;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private EstadoPresupuesto estado = EstadoPresupuesto.BORRADOR;

    @Column(name = "fecha_aprobacion")
    private LocalDateTime fechaAprobacion;

    @ManyToOne
    @JoinColumn(name = "usuario_aprobador_id")
    private Usuario usuarioAprobador;
}
