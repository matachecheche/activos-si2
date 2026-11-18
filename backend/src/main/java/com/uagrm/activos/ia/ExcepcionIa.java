package com.uagrm.activos.ia;

/**
 * Fallo de un proveedor de IA con el detalle accionable para el usuario:
 * codigo HTTP (0 si fue un problema de red/timeout), mensaje del proveedor y
 * una marca que distingue los rechazos por modelo retirado o sin acceso.
 */
public class ExcepcionIa extends Exception {

    private final int httpStatus;
    private final boolean errorDeModelo;

    public ExcepcionIa(String mensaje, int httpStatus, boolean errorDeModelo) {
        super(mensaje);
        this.httpStatus = httpStatus;
        this.errorDeModelo = errorDeModelo;
    }

    public int getHttpStatus() {
        return httpStatus;
    }

    public boolean isErrorDeModelo() {
        return errorDeModelo;
    }
}
