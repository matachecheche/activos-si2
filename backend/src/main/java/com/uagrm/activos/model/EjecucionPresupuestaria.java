package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * HU-10: compromisos y ejecuciones por partida. Una ejecucion puede referenciar un
 * compromiso previo (compromiso_id); en ese caso el compromiso queda liberado.
 */
@Entity
@Table(name = "ejecucion_presupuestaria")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EjecucionPresupuestaria {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "partida_id")
    private PartidaPresupuestaria partida;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(nullable = false, length = 200)
    private String concepto;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal monto;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TipoEjecucion tipo;

    @ManyToOne
    @JoinColumn(name = "activo_id")
    private Activo activo; // activo adquirido (opcional)

    @ManyToOne
    @JoinColumn(name = "compromiso_id")
    private EjecucionPresupuestaria compromiso; // compromiso que esta ejecucion libera (opcional)

    @ManyToOne
    @JoinColumn(name = "usuario_id")
    private Usuario usuario;
}
