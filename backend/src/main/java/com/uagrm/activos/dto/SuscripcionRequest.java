package com.uagrm.activos.dto;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SuscripcionRequest {
    @NotNull
    private Long planId;
    @NotBlank @Size(max = 30)
    private String metodoPago;
    @Min(1) @Max(36)
    private int meses = 1;
}
