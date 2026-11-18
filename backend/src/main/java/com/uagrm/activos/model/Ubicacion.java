package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "ubicacion")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Ubicacion {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nombre; // ej. area/departamento/oficina

    // Sprint 2: lugar fisico asociado a un area (opcional para no romper datos de Sprint 1)
    @ManyToOne
    @JoinColumn(name = "area_id")
    private Area area;
}
