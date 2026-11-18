package com.uagrm.activos.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

/** HU-16: metadata de cada respaldo generado. empresaId null = respaldo de plataforma. */
@Entity
@Table(name = "respaldo")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Respaldo {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "empresa_id")
    private Long empresaId;
    @Column(nullable = false, length = 20)
    private String tipo;                 // MANUAL | PROGRAMADO | PLATAFORMA | SEGURIDAD
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String destino = "LOCAL";   // LOCAL | NUBE
    @Column(nullable = false)
    private String archivo;
    @Column(name = "tamano_bytes", nullable = false)
    private long tamanoBytes;
    @Column(nullable = false, length = 64)
    private String sha256;
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String estado = "COMPLETADO";
    @Column(name = "usuario_id")
    private Long usuarioId;

    /**
     * Copia del archivo de respaldo guardada en la base. En App Service el
     * disco del contenedor es efimero, asi que sin esta copia los respaldos
     * desaparecerian al reiniciar o desplegar. No se serializa en el JSON.
     */
    @JsonIgnore
    @Column(name = "contenido", columnDefinition = "bytea")
    private byte[] contenido;

    /**
     * Indica si el contenido sigue disponible para descargar/restaurar.
     * Los respaldos muy antiguos (o los de demostracion) solo guardaban la
     * ruta del archivo: si ese archivo ya no existe, no hay nada que bajar.
     * La web usa esta bandera para explicar en vez de mostrar un error 404.
     */
    public boolean isDescargable() {
        if (contenido != null && contenido.length > 0) return true;
        try {
            return archivo != null && !archivo.isBlank() && java.nio.file.Files.exists(java.nio.file.Path.of(archivo));
        } catch (Exception e) {
            return false;
        }
    }
    @Column(nullable = false)
    @Builder.Default
    private LocalDateTime fecha = LocalDateTime.now();

    /**
     * Nombre del archivo tal como lo descarga el usuario (sin la ruta del
     * servidor, que no tiene sentido en el navegador ni en el telefono).
     */
    @com.fasterxml.jackson.annotation.JsonProperty("nombreArchivo")
    public String getNombreArchivo() {
        if (archivo == null || archivo.isBlank()) {
            return "respaldo_" + id + ".afb";
        }
        int separador = Math.max(archivo.lastIndexOf('/'), archivo.lastIndexOf('\\'));
        return separador >= 0 ? archivo.substring(separador + 1) : archivo;
    }
}
