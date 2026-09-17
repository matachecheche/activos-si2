package com.uagrm.activos.dto;

import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AsignacionRequest {
    private Long activoId;
    private Long responsableId;
    private Long ubicacionId;
}
