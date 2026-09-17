package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "usuario")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Usuario {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nombre;

    @Column(nullable = false, unique = true, length = 150)
    private String correo; // correo institucional (HU-01)

    @Column(nullable = false)
    private String password; // almacenado con BCrypt

    @ManyToOne(optional = false)
    @JoinColumn(name = "rol_id")
    private Rol rol;

    @Builder.Default
    private Integer intentosFallidos = 0;

    private LocalDateTime bloqueadoHasta; // bloqueo individual temporal tras 3 intentos

    @Builder.Default
    private Boolean activo = true;
}
