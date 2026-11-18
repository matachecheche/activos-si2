package com.uagrm.activos.auditoria;

import java.lang.annotation.*;

/**
 * HU-13: marca un metodo de servicio para registrar la operacion en la
 * bitacora inmutable. idExpresion/detalleExpresion son expresiones SpEL
 * sobre los argumentos (#a0, #a1, ...) y el valor de retorno (#resultado).
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Auditable {
    String accion();
    String entidad();
    String idExpresion() default "";
    String detalleExpresion() default "";
}
