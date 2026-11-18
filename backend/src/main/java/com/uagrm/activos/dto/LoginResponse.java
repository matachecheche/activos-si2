package com.uagrm.activos.dto;

import lombok.*;
import java.util.List;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LoginResponse {
    private String token;
    private String nombre;
    private String rol;
    private List<String> permisos;
    private Long empresaId;      // Sprint 3 HU-12
    private String nivel;        // SUPER_ADMIN | ADMIN | REGULAR
    private String empresaNombre;
    /** Correo de la cuenta global (para mostrarlo y reutilizarlo en el alta
     *  de otra empresa sin volver a escribirlo). */
    private String correo;
    /** Sprint 3 / multiempresa: empresas a las que el usuario tiene acceso. */
    private List<EmpresaSesionDto> empresas;
}
