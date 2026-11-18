package com.uagrm.activos.security;

/**
 * Expresiones de autorizacion reutilizables para @PreAuthorize. Cada permiso tiene la forma
 * MODULO_ACCION (p. ej. PRESUPUESTO_CREAR) y viaja en el JWT. El administrador tiene acceso total.
 *
 * <p>El Super Admin de la plataforma (HU-12) tiene tambien acceso total: administra todas las
 * empresas, asi que tambien puede ver y editar roles, permisos, areas y usuarios.</p>
 */
public final class Autorizacion {

    private Autorizacion() {
    }

    public static final String ADMIN = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN')";

    public static final String ACTIVOS_LEER = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_ACTIVOS_LEER')";
    public static final String ACTIVOS_CREAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_ACTIVOS_CREAR')";
    public static final String ACTIVOS_EDITAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_ACTIVOS_EDITAR')";

    public static final String CATEGORIAS_LEER = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_ACTIVOS_LEER') or hasAuthority('PERM_DEPRECIACION_LEER')";
    public static final String CATEGORIAS_EDITAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_ACTIVOS_EDITAR') or hasAuthority('PERM_DEPRECIACION_EDITAR')";

    public static final String DEPRECIACION_LEER = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_DEPRECIACION_LEER')";
    public static final String DEPRECIACION_CREAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_DEPRECIACION_CREAR')";

    public static final String MANTENIMIENTO_LEER = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_MANTENIMIENTO_LEER') or hasAuthority('PERM_ACTIVOS_LEER')";
    public static final String MANTENIMIENTO_CREAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_MANTENIMIENTO_CREAR')";
    public static final String MANTENIMIENTO_EDITAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_MANTENIMIENTO_EDITAR')";

    public static final String PRESUPUESTO_LEER = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_PRESUPUESTO_LEER')";
    public static final String PRESUPUESTO_CREAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_PRESUPUESTO_CREAR')";
    public static final String PRESUPUESTO_EDITAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_PRESUPUESTO_EDITAR')";
    public static final String PRESUPUESTO_ELIMINAR = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_PRESUPUESTO_ELIMINAR')";

    public static final String AREAS_LEER = "hasRole('ADMINISTRADOR') or hasRole('SUPER_ADMIN') or hasAuthority('PERM_PRESUPUESTO_LEER') or hasAuthority('PERM_ACTIVOS_LEER')";
}
