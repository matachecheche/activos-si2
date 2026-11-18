package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** HU-07: una fila por activo y periodo (yyyy-MM). La combinacion activo-periodo es unica. */
@Entity
@Table(name = "depreciacion_activo",
        uniqueConstraints = @UniqueConstraint(name = "uk_depreciacion_activo_periodo", columnNames = {"activo_id", "periodo"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class DepreciacionActivo {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "activo_id")
    private Activo activo;

    @Column(nullable = false, length = 7)
    private String periodo; // yyyy-MM

    @Column(name = "depreciacion_periodo", nullable = false, precision = 14, scale = 2)
    private BigDecimal depreciacionPeriodo;

    @Column(name = "depreciacion_acumulada", nullable = false, precision = 14, scale = 2)
    private BigDecimal depreciacionAcumulada;

    @Column(name = "valor_en_libros", nullable = false, precision = 14, scale = 2)
    private BigDecimal valorEnLibros;

    @Column(name = "fecha_calculo", nullable = false)
    private LocalDateTime fechaCalculo;
}
