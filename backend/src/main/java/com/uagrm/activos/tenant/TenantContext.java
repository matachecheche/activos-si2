package com.uagrm.activos.tenant;

/**
 * HU-11/HU-12: identidad multiempresa de la peticion actual.
 * Lo llena JwtAuthFilter con los claims del JWT; lo leen el filtro Hibernate
 * y el listener de persistencia. Nivel SUPER_ADMIN no tiene empresaId.
 */
public final class TenantContext {

    public static final String NIVEL_SUPER_ADMIN = "SUPER_ADMIN";
    public static final String NIVEL_ADMIN = "ADMIN";
    public static final String NIVEL_REGULAR = "REGULAR";

    private static final ThreadLocal<Long> EMPRESA = new ThreadLocal<>();
    private static final ThreadLocal<String> NIVEL = new ThreadLocal<>();
    private static final ThreadLocal<String> CORREO = new ThreadLocal<>();
    private static final ThreadLocal<String> IP = new ThreadLocal<>();
    private static final ThreadLocal<String> EQUIPO = new ThreadLocal<>();
    private static final ThreadLocal<Long> USUARIO_ID = new ThreadLocal<>();

    private TenantContext() {
    }

    public static void setEmpresaId(Long id) { EMPRESA.set(id); }
    public static Long getEmpresaId() { return EMPRESA.get(); }
    public static void setNivel(String n) { NIVEL.set(n); }
    public static String getNivel() { return NIVEL.get(); }
    public static boolean esSuperAdmin() { return NIVEL_SUPER_ADMIN.equals(NIVEL.get()); }
    public static void setCorreo(String c) { CORREO.set(c); }
    public static String getCorreo() { return CORREO.get(); }
    public static void setIp(String ip) { IP.set(ip); }
    public static String getIp() { return IP.get(); }
    public static void setEquipo(String e) { EQUIPO.set(e); }
    public static String getEquipo() { return EQUIPO.get(); }
    public static void setUsuarioId(Long id) { USUARIO_ID.set(id); }
    public static Long getUsuarioId() { return USUARIO_ID.get(); }

    public static void limpiar() {
        EMPRESA.remove();
        NIVEL.remove();
        CORREO.remove();
        IP.remove();
        EQUIPO.remove();
        USUARIO_ID.remove();
    }
}
