package com.uagrm.activos.model;

import jakarta.persistence.*;
import org.hibernate.annotations.TenantId;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.*;
import java.time.LocalDateTime;

/** HU-14: definicion de una consulta dinamica reutilizable (JSON con campos/filtros). */
@Entity
@Table(name = "consulta_guardada")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ConsultaGuardada {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;
    @Column(name = "usuario_id")
    private Long usuarioId;
    @Column(nullable = false, length = 150)
    private String nombre;
    @Column(nullable = false, length = 80)
    private String entidad;
    @Column(nullable = false, columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String definicion;
    @Column(nullable = false)
    @Builder.Default
    private LocalDateTime fecha = LocalDateTime.now();
}
