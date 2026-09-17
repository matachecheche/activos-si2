package com.uagrm.activos.dto;

import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class LoginRequest {
    private String correo;
    private String password;
}
