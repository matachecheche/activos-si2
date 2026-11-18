package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Sprint 3 / multiempresa: identidad global de la persona.
 *
 * Antes el login vivia en la tabla `usuario`, que esta particionada por
 * empresa_id: eso impedia que una misma persona usara dos empresas con un
 * solo login. Ahora `cuenta` guarda la identidad (correo, contrasena, estado)
 * y cada fila de `usuario` es la MEMBRESIA de esa persona en una empresa
 * (con su rol). Un solo login, varias empresas, cambio de empresa sin
 * volver a autenticarse.
 *
 * No lleva @TenantId a proposito: es una tabla global, compartida por todos
 * los tenants de la plataforma.
 */
@Entity
@Table(name = "cuenta")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Cuenta {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 150)
    private String correo;

    @Column(nullable = false, length = 150)
    private String nombre;

    /** Hash BCrypt. */
    @Column(nullable = false, length = 200)
    private String password;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String nivel = "REGULAR"; // SUPER_ADMIN | ADMIN | REGULAR

    @Builder.Default
    private Integer intentosFallidos = 0;

    private LocalDateTime bloqueadoHasta;

    @Builder.Default
    private Boolean activo = true;

    @Builder.Default
    private LocalDateTime fechaRegistro = LocalDateTime.now();
}
