package com.uagrm.activos.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.*;

/** HU-15: tema, logotipo, idioma y disposicion del menu por empresa. */
@Entity
@Table(name = "configuracion_empresa")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ConfiguracionEmpresa {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "empresa_id", nullable = false, unique = true)
    private Long empresaId;
    @Column(name = "color_primario", nullable = false, length = 20)
    @Builder.Default
    private String colorPrimario = "#2c5cc5";
    @Column(name = "color_secundario", nullable = false, length = 20)
    @Builder.Default
    private String colorSecundario = "#0f2a5c";
    @Column(columnDefinition = "bytea")
    private byte[] logo;
    @Column(name = "logo_nombre")
    private String logoNombre;
    @Column(name = "logo_tipo")
    private String logoTipo;
    @Column(nullable = false, length = 5)
    @Builder.Default
    private String idioma = "es";
    @Column(name = "menu_config", columnDefinition = "jsonb", nullable = false)
    @JdbcTypeCode(SqlTypes.JSON)
    @Builder.Default
    private String menuConfig = "[]";
}
