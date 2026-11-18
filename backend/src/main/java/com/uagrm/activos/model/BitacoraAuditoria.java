package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

/**
 * HU-13: bitacora inmutable (caja negra). La aplicacion solo inserta y consulta;
 * un disparador en la base rechaza UPDATE/DELETE/TRUNCATE. hashRegistro encadena
 * el hash del registro anterior para detectar alteraciones.
 */
@Entity
@Table(name = "bitacora_auditoria")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class BitacoraAuditoria {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "empresa_id")
    private Long empresaId;
    @Column(name = "usuario_id")
    private Long usuarioId;
    @Column(name = "usuario_nombre", length = 150)
    private String usuarioNombre;
    @Column(nullable = false, length = 50)
    private String accion;
    @Column(nullable = false, length = 80)
    private String entidad;
    @Column(name = "entidad_id", length = 50)
    private String entidadId;
    @Column(columnDefinition = "text")
    private String detalle;
    @Column(length = 45)
    private String ip;
    @Column(length = 255)
    private String equipo;
    @Column(name = "fecha_hora", nullable = false)
    @Builder.Default
    private LocalDateTime fechaHora = LocalDateTime.now();
    @Column(name = "hash_anterior", length = 64)
    private String hashAnterior;
    @Column(name = "hash_registro", nullable = false, length = 64)
    private String hashRegistro;
}
