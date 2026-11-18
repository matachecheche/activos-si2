package com.uagrm.activos.model;

import jakarta.persistence.Column;
import org.hibernate.annotations.TenantId;

import jakarta.persistence.*;
import lombok.*;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "rol")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Rol {

    @TenantId
    @Column(name = "empresa_id")
    private Long empresaId;


    @Column(name = "es_sistema", nullable = false)
    @lombok.Builder.Default
    private boolean esSistema = false;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String nombre;

    @Column(length = 160)
    private String descripcion;

    // HU-04: un rol puede desactivarse (estado activo/inactivo)
    @Builder.Default
    private Boolean activo = true;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "rol_permiso",
            joinColumns = @JoinColumn(name = "rol_id"),
            inverseJoinColumns = @JoinColumn(name = "permiso_id"))
    @Builder.Default
    private Set<Permiso> permisos = new HashSet<>();

    public boolean estaActivo() {
        return !Boolean.FALSE.equals(activo);
    }
}
