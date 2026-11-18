package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

/** HU-16: programacion (diaria/semanal) y retencion de copias por empresa. */
@Entity
@Table(name = "programacion_respaldo")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ProgramacionRespaldo {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "empresa_id", nullable = false, unique = true)
    private Long empresaId;
    @Column(nullable = false, length = 10)
    private String frecuencia;           // DIARIA | SEMANAL
    @Column(nullable = false, length = 5)
    @Builder.Default
    private String hora = "02:00";
    @Column(name = "copias_a_conservar", nullable = false)
    @Builder.Default
    private int copiasAConservar = 3;
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String destino = "LOCAL";
    @Column(nullable = false)
    @Builder.Default
    private boolean activa = true;
}
