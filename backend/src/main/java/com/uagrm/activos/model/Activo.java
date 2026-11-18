package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "activo")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Activo {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 30)
    private String codigo; // HU-02: codigo unico generado por el sistema

    @Column(nullable = false, length = 150)
    private String nombre;

    @ManyToOne(optional = false)
    @JoinColumn(name = "categoria_id")
    private Categoria categoria;

    @Column(nullable = false)
    private BigDecimal valor; // valor de adquisicion (HU-02: no puede ser negativo ni cero)

    @Column(name = "fecha_adquisicion", nullable = false)
    private LocalDate fechaAdquisicion;

    @Column(length = 150)
    private String proveedor;

    private String observaciones;

    // HU-06: estado controlado por EstadoActivoService
    @Convert(converter = EstadoActivoConverter.class)
    @Column(length = 30)
    @Builder.Default
    private EstadoActivo estado = EstadoActivo.DISPONIBLE;

    @ManyToOne
    @JoinColumn(name = "responsable_id")
    private Usuario responsable; // HU-03

    @ManyToOne
    @JoinColumn(name = "ubicacion_id")
    private Ubicacion ubicacion; // HU-03

    // HU-07: depreciacion
    @Column(name = "valor_residual", precision = 14, scale = 2)
    private BigDecimal valorResidual;

    @Column(name = "fecha_inicio_depreciacion")
    private LocalDate fechaInicioDepreciacion;

    // HU-06/HU-07: fecha en que se dio de baja (deja de depreciarse)
    @Column(name = "fecha_baja")
    private LocalDate fechaBaja;

    @Column(name = "foto_url", length = 500)
    private String fotoUrl;
}
