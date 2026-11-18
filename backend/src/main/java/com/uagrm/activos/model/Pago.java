package com.uagrm.activos.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/** HU-11: transaccion de pago de una suscripcion (pasarela sandbox en esta etapa). */
@Entity
@Table(name = "pago")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Pago {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(optional = false)
    @JoinColumn(name = "suscripcion_id", nullable = false)
    private Suscripcion suscripcion;
    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal monto;
    @Column(nullable = false, length = 30)
    private String metodo;

    /** Sprint 3: pasarela real usada (MERCADO_PAGO | PAYPAL | SANDBOX | SISTEMA). */
    @Column(nullable = false, length = 30)
    @Builder.Default
    private String proveedor = "SISTEMA";

    /** Identificador del checkout en la pasarela (preference / order). */
    @Column(name = "checkout_id", length = 150)
    private String checkoutId;

    /** Momento en que la pasarela confirmo el pago. */
    @Column(name = "fecha_aprobacion")
    private LocalDateTime fechaAprobacion;
    @Column(length = 100)
    private String referencia;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private EstadoPago estado = EstadoPago.PENDIENTE;
    @Column(columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String detalle;
    @Column(nullable = false)
    @Builder.Default
    private LocalDateTime fecha = LocalDateTime.now();
}
