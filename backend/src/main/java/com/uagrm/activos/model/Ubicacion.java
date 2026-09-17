package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "ubicacion")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Ubicacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nombre; // ej. area/departamento/oficina
}
