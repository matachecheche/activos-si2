package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "activo")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Activo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 30)
    private String codigo; // HU-02: codigo unico generado por el sistema

    @Column(nullable = false, length = 150)
    private String nombre;

    @ManyToOne(optional = false)
    @JoinColumn(name = "categoria_id")
    private Categoria categoria;

    @Column(nullable = false)
    private BigDecimal valor; // HU-02: no puede ser negativo ni cero

    @Column(name = "fecha_adquisicion", nullable = false)
    private LocalDate fechaAdquisicion;

    @Column(length = 150)
    private String proveedor;

    private String observaciones;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private EstadoActivo estado = EstadoActivo.SIN_ASIGNAR;

    @ManyToOne
    @JoinColumn(name = "responsable_id")
    private Usuario responsable; // HU-03

    @ManyToOne
    @JoinColumn(name = "ubicacion_id")
    private Ubicacion ubicacion; // HU-03
}
