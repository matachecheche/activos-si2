package com.uagrm.activos.model;

import jakarta.persistence.*;
import org.hibernate.annotations.TenantId;
import lombok.*;
import java.time.LocalDateTime;

/** HU-17: verificacion fisica de un activo registrada desde el movil con GPS. */
@Entity
@Table(name = "verificacion_inventario")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class VerificacionInventario {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;
    @Column(name = "activo_id", nullable = false)
    private Long activoId;
    @Column(name = "usuario_id")
    private Long usuarioId;
    @Column(name = "fecha_hora", nullable = false)
    @Builder.Default
    private LocalDateTime fechaHora = LocalDateTime.now();
    private Double latitud;
    private Double longitud;
    @Column(name = "precision_m")
    private Double precisionM;
    @Column(nullable = false, length = 25)
    private String resultado;            // ENCONTRADO | NO_ENCONTRADO | DIFERENCIA_ESTADO
    @Column(name = "foto_url", length = 500)
    private String fotoUrl;
    @Column(length = 500)
    private String observacion;
}
