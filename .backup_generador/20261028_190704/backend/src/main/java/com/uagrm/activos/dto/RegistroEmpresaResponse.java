package com.uagrm.activos.dto;

import lombok.*;
import java.time.LocalDateTime;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class RegistroEmpresaResponse {
    private Long empresaId;
    private String nombreEmpresa;
    private String estado;
    private Long suscripcionId;
    private String plan;
    private LocalDateTime vencimiento;
    private Long pagoId;
    private String referenciaPago;
    private String estadoPago;
    private String correoAdmin;
    private String mensaje;
}
