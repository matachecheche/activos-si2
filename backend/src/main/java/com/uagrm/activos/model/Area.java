package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

/** Area o departamento de la organizacion (duena de un presupuesto por gestion). */
@Entity
@Table(name = "area")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Area {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String nombre;

    @Column(length = 200)
    private String descripcion;

    @Builder.Default
    private Boolean activo = true;
}
