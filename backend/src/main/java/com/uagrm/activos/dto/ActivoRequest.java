package com.uagrm.activos.dto;

import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ActivoRequest {
    private String nombre;
    private Long categoriaId;
    private BigDecimal valor;
    private LocalDate fechaAdquisicion;
    private String proveedor;
    private String observaciones;
}
