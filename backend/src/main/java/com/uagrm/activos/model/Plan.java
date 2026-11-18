package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;

/** HU-11: limites y funciones habilitadas por plan (11.8.8). Editables sin tocar codigo. */
@Entity
@Table(name = "plan")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Plan {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, unique = true, length = 50)
    private String nombre;
    @Column(name = "precio_mensual", nullable = false, precision = 12, scale = 2)
    private BigDecimal precioMensual;
    @Column(name = "max_usuarios")
    private Integer maxUsuarios;          // null = ilimitado
    @Column(name = "max_activos")
    private Long maxActivos;               // null = ilimitado
    @Column(name = "incluye_bi", nullable = false)
    private boolean incluyeBi;
    @Column(name = "incluye_consultas_dinamicas", nullable = false)
    private boolean incluyeConsultasDinamicas;
    @Column(name = "respaldo_programado", nullable = false)
    private boolean respaldoProgramado;
    @Column(name = "respaldo_nube", nullable = false)
    private boolean respaldoNube;
    @Column(name = "idioma_adicional", nullable = false)
    private boolean idiomaAdicional;
    @Column(name = "personalizacion_completa", nullable = false)
    private boolean personalizacionCompleta;
    @Column(nullable = false)
    @Builder.Default
    private boolean activo = true;
}
