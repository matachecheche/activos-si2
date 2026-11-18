package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

/** HU-11: cliente SaaS (institucion que contrata una suscripcion). */
@Entity
@Table(name = "empresa")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Empresa {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 150)
    private String nombre;
    @Column(length = 30)
    private String nit;
    @Column(length = 100)
    private String rubro;
    @Column(name = "correo_contacto", nullable = false, length = 150)
    private String correoContacto;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private EstadoEmpresa estado = EstadoEmpresa.ACTIVA;
    @Column(name = "fecha_registro", nullable = false)
    @Builder.Default
    private LocalDateTime fechaRegistro = LocalDateTime.now();
}
