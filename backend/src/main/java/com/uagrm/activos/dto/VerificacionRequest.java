package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotNull;
import lombok.*;

/** HU-17: verificacion fisica enviada desde el movil (GPS y foto opcionales). */
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class VerificacionRequest {
    @NotNull
    private Long activoId;
    @NotNull
    private String resultado;       // ENCONTRADO | NO_ENCONTRADO | DIFERENCIA_ESTADO
    private Double latitud;
    private Double longitud;
    private Double precisionM;
    private String observacion;
    private String fotoUrl;         // URL devuelta previamente por /api/inventario/foto
}
