package com.uagrm.activos.dto;

import lombok.*;
import java.util.List;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LoginResponse {
    private String token;
    private String nombre;
    private String rol;
    private List<String> permisos;
}
