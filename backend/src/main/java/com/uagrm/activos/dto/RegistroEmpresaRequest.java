package com.uagrm.activos.dto;

import jakarta.validation.constraints.*;
import lombok.*;

/** HU-11: formulario publico de alta de una empresa SaaS. */
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class RegistroEmpresaRequest {
    @NotBlank(message = "El nombre de la empresa es obligatorio")
    @Size(max = 150)
    private String nombreEmpresa;
    @Size(max = 30)
    private String nit;
    @Size(max = 100)
    private String rubro;
    @NotBlank @Email @Size(max = 150)
    private String correoContacto;
    @NotNull
    private Long planId;
    @NotBlank @Size(min = 3, max = 120)
    private String nombreAdmin;
    @NotBlank @Email @Size(max = 150)
    private String correoAdmin;
    @NotBlank @Size(min = 6, max = 100)
    private String passwordAdmin;
    @NotBlank @Size(max = 30)
    private String metodoPago;   // TARJETA_SANDBOX | TRANSFERENCIA
    @Min(1) @Max(36)
    private int meses = 1;
}
