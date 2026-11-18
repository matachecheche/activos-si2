package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "categoria")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Categoria {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // HU-02: Mobiliario, Equipos informaticos, Vehiculos, Maquinaria, Inmuebles, Terrenos
    @Column(nullable = false, length = 100)
    private String nombre;

    // HU-07: parametros de depreciacion por categoria
    @Column(name = "vida_util")
    private Integer vidaUtil; // en anios (null en categorias no depreciables)

    @Column(name = "metodo_depreciacion", length = 30)
    private String metodoDepreciacion; // LINEA_RECTA

    @Column(name = "valor_residual_pct", precision = 5, scale = 2)
    private BigDecimal valorResidualPct;

    private Boolean depreciable;

    public boolean esDepreciable() {
        return Boolean.TRUE.equals(depreciable) && vidaUtil != null && vidaUtil > 0;
    }
}
