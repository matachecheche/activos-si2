package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "usuario")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Usuario {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Column(length = 20)
    @lombok.Builder.Default
    private String nivel = "REGULAR";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nombre;

    /**
     * Sprint 3 / multiempresa: el correo ya no es unico global (una persona
     * puede tener una membresia en varias empresas). La unicidad real es
     * (empresa_id, correo) y la identidad global vive en `cuenta`.
     */
    @Column(nullable = false, length = 150)
    private String correo; // correo institucional (HU-01)

    /** Cuenta global a la que pertenece esta membresia. */
    @Column(name = "cuenta_id")
    private Long cuentaId;

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
