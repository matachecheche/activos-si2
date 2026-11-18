package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "permiso", uniqueConstraints = @UniqueConstraint(columnNames = {"modulo", "accion"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Permiso {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String modulo;

    @Column(nullable = false, length = 20)
    private String accion;

    @Column(nullable = false, length = 160)
    private String descripcion;
}
