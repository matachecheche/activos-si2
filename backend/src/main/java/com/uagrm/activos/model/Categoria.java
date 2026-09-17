package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "categoria")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Categoria {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // HU-02: Mobiliario, Equipos informaticos, Vehiculos, Maquinaria, Inmuebles
    @Column(nullable = false, unique = true, length = 100)
    private String nombre;
}
