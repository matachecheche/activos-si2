package com.uagrm.activos.dto;

import lombok.*;

import java.util.List;

/**
 * Sprint 3 / multiempresa: una empresa a la que la persona tiene acceso, con el
 * rol y los permisos que tiene EN esa empresa. Sirve para listar las empresas
 * en el selector y para reautenticar al cambiar.
 */
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmpresaSesionDto {
    private Long empresaId;
    private String empresaNombre;
    private String nit;
    private String rol;
    private List<String> permisos;
    /** true si es la empresa con la que se inicio la sesion. */
    private Boolean actual;
}
