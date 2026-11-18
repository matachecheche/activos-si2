package com.uagrm.activos.ia;

import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * HU-14: lista blanca unica del motor text-to-SQL. Ninguna tabla, columna ni
 * operador que no este aqui puede llegar al SQL. Todas las tablas son de
 * negocio y tienen empresa_id; el motor siempre anida el scope por empresa.
 */
@Component
public class CatalogoSql {

    public static final List<String> OPERADORES =
            List.of("=", "!=", ">", ">=", "<", "<=", "LIKE", "NOT LIKE", "IN", "BETWEEN", "IS NULL", "IS NOT NULL");

    private final Map<String, TablaCatalogo> tablas = new LinkedHashMap<>();

    public CatalogoSql() {
        registrar(new TablaCatalogo("activo", "Activos", "Bienes o activos fijos de la empresa", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("codigo", TipoColumna.TEXTO, "Codigo del activo"),
                new ColumnaCatalogo("nombre", TipoColumna.TEXTO, "Nombre del activo"),
                new ColumnaCatalogo("estado", TipoColumna.ENUM, "Estado (DISPONIBLE, ASIGNADO, EN_MANTENIMIENTO, DADO_DE_BAJA)"),
                new ColumnaCatalogo("valor", TipoColumna.NUMERO, "Valor de adquisicion en bolivianos"),
                new ColumnaCatalogo("valor_residual", TipoColumna.NUMERO, "Valor residual"),
                new ColumnaCatalogo("fecha_adquisicion", TipoColumna.FECHA, "Fecha de adquisicion"),
                new ColumnaCatalogo("fecha_baja", TipoColumna.FECHA, "Fecha de baja"),
                new ColumnaCatalogo("proveedor", TipoColumna.TEXTO, "Proveedor"),
                new ColumnaCatalogo("categoria_id", TipoColumna.NUMERO, "Identificador de categoria"),
                new ColumnaCatalogo("ubicacion_id", TipoColumna.NUMERO, "Identificador de ubicacion"),
                new ColumnaCatalogo("responsable_id", TipoColumna.NUMERO, "Identificador del usuario responsable"),
                new ColumnaCatalogo("foto_url", TipoColumna.TEXTO, "URL de la fotografia"))));

        registrar(new TablaCatalogo("categoria", "Categorias", "Categorias de activos", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("nombre", TipoColumna.TEXTO, "Nombre de la categoria"),
                new ColumnaCatalogo("vida_util", TipoColumna.NUMERO, "Vida util en anos"),
                new ColumnaCatalogo("metodo_depreciacion", TipoColumna.TEXTO, "Metodo de depreciacion"),
                new ColumnaCatalogo("valor_residual_pct", TipoColumna.NUMERO, "Porcentaje de valor residual"),
                new ColumnaCatalogo("depreciable", TipoColumna.BOOLEANO, "Si la categoria es depreciable"))));

        registrar(new TablaCatalogo("ubicacion", "Ubicaciones", "Ubicaciones fisicas de los activos", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("nombre", TipoColumna.TEXTO, "Nombre de la ubicacion"),
                new ColumnaCatalogo("area_id", TipoColumna.NUMERO, "Identificador del area"))));

        registrar(new TablaCatalogo("area", "Areas", "Areas organizacionales", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("nombre", TipoColumna.TEXTO, "Nombre del area"),
                new ColumnaCatalogo("descripcion", TipoColumna.TEXTO, "Descripcion"))));

        registrar(new TablaCatalogo("mantenimiento", "Mantenimientos", "Mantenimientos preventivos y correctivos", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("activo_id", TipoColumna.NUMERO, "Identificador del activo"),
                new ColumnaCatalogo("tipo", TipoColumna.ENUM, "Tipo (PREVENTIVO, CORRECTIVO)"),
                new ColumnaCatalogo("estado", TipoColumna.ENUM, "Estado (PROGRAMADO, EN_PROCESO, COMPLETADO, CANCELADO)"),
                new ColumnaCatalogo("costo", TipoColumna.NUMERO, "Costo en bolivianos"),
                new ColumnaCatalogo("fecha_programada", TipoColumna.FECHA, "Fecha programada"),
                new ColumnaCatalogo("fecha_realizada", TipoColumna.FECHA, "Fecha de realizacion"),
                new ColumnaCatalogo("tecnico", TipoColumna.TEXTO, "Tecnico asignado"))));

        registrar(new TablaCatalogo("depreciacion_activo", "Depreciaciones", "Calculo mensual de depreciacion de activos", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("activo_id", TipoColumna.NUMERO, "Identificador del activo"),
                new ColumnaCatalogo("periodo", TipoColumna.TEXTO, "Periodo yyyy-MM"),
                new ColumnaCatalogo("depreciacion_periodo", TipoColumna.NUMERO, "Depreciacion del periodo"),
                new ColumnaCatalogo("depreciacion_acumulada", TipoColumna.NUMERO, "Depreciacion acumulada"),
                new ColumnaCatalogo("valor_en_libros", TipoColumna.NUMERO, "Valor en libros"),
                new ColumnaCatalogo("fecha_calculo", TipoColumna.FECHA, "Fecha del calculo"))));

        registrar(new TablaCatalogo("historial_estado_activo", "Historial de estados", "Cambios de estado de los activos", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("activo_id", TipoColumna.NUMERO, "Identificador del activo"),
                new ColumnaCatalogo("estado_anterior", TipoColumna.ENUM, "Estado anterior"),
                new ColumnaCatalogo("estado_nuevo", TipoColumna.ENUM, "Estado nuevo"),
                new ColumnaCatalogo("motivo", TipoColumna.TEXTO, "Motivo del cambio"),
                new ColumnaCatalogo("usuario_id", TipoColumna.NUMERO, "Identificador del usuario"),
                new ColumnaCatalogo("fecha", TipoColumna.FECHA, "Fecha del cambio"))));

        registrar(new TablaCatalogo("asignacion", "Asignaciones", "Asignacion de activos a responsables", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("activo_id", TipoColumna.NUMERO, "Identificador del activo"),
                new ColumnaCatalogo("responsable_id", TipoColumna.NUMERO, "Identificador del usuario responsable"),
                new ColumnaCatalogo("ubicacion_id", TipoColumna.NUMERO, "Identificador de la ubicacion"),
                new ColumnaCatalogo("fecha_asignacion", TipoColumna.FECHA, "Fecha de asignacion"),
                new ColumnaCatalogo("activa", TipoColumna.BOOLEANO, "Si la asignacion sigue activa"))));

        registrar(new TablaCatalogo("presupuesto", "Presupuestos", "Presupuestos anuales por area", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("area_id", TipoColumna.NUMERO, "Identificador del area"),
                new ColumnaCatalogo("gestion", TipoColumna.NUMERO, "Gestion o ano"),
                new ColumnaCatalogo("monto_aprobado", TipoColumna.NUMERO, "Monto aprobado"),
                new ColumnaCatalogo("fecha_aprobacion", TipoColumna.FECHA, "Fecha de aprobacion"),
                new ColumnaCatalogo("estado", TipoColumna.ENUM, "Estado del presupuesto"))));

        registrar(new TablaCatalogo("partida_presupuestaria", "Partidas", "Partidas dentro de un presupuesto", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("presupuesto_id", TipoColumna.NUMERO, "Identificador del presupuesto"),
                new ColumnaCatalogo("codigo", TipoColumna.TEXTO, "Codigo de partida"),
                new ColumnaCatalogo("nombre", TipoColumna.TEXTO, "Nombre de la partida"),
                new ColumnaCatalogo("monto_planificado", TipoColumna.NUMERO, "Monto planificado"))));

        registrar(new TablaCatalogo("ejecucion_presupuestaria", "Ejecuciones", "Ejecucion de partidas presupuestarias", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("partida_id", TipoColumna.NUMERO, "Identificador de la partida"),
                new ColumnaCatalogo("monto", TipoColumna.NUMERO, "Monto ejecutado"),
                new ColumnaCatalogo("fecha", TipoColumna.FECHA, "Fecha de la ejecucion"),
                new ColumnaCatalogo("concepto", TipoColumna.TEXTO, "Concepto"),
                new ColumnaCatalogo("tipo", TipoColumna.ENUM, "Tipo de ejecucion"))));

        registrar(new TablaCatalogo("usuario", "Usuarios", "Usuarios de la empresa", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("nombre", TipoColumna.TEXTO, "Nombre completo"),
                new ColumnaCatalogo("correo", TipoColumna.TEXTO, "Correo institucional"),
                new ColumnaCatalogo("nivel", TipoColumna.ENUM, "Nivel (ADMIN, REGULAR)"),
                new ColumnaCatalogo("activo", TipoColumna.BOOLEANO, "Si la cuenta esta activa"),
                new ColumnaCatalogo("intentos_fallidos", TipoColumna.NUMERO, "Intentos fallidos de login"))));

        registrar(new TablaCatalogo("verificacion_inventario", "Verificaciones de inventario", "Verificaciones fisicas registradas desde el movil (HU-17)", List.of(
                new ColumnaCatalogo("id", TipoColumna.NUMERO, "Identificador"),
                new ColumnaCatalogo("activo_id", TipoColumna.NUMERO, "Identificador del activo"),
                new ColumnaCatalogo("usuario_id", TipoColumna.NUMERO, "Identificador del usuario"),
                new ColumnaCatalogo("fecha_hora", TipoColumna.FECHA, "Fecha y hora de la verificacion"),
                new ColumnaCatalogo("latitud", TipoColumna.NUMERO, "Latitud GPS"),
                new ColumnaCatalogo("longitud", TipoColumna.NUMERO, "Longitud GPS"),
                new ColumnaCatalogo("precision_m", TipoColumna.NUMERO, "Precision GPS en metros"),
                new ColumnaCatalogo("resultado", TipoColumna.ENUM, "Resultado (ENCONTRADO, NO_ENCONTRADO, DIFERENCIA_ESTADO)"),
                new ColumnaCatalogo("observacion", TipoColumna.TEXTO, "Observacion"))));
    }

    private void registrar(TablaCatalogo tabla) {
        tablas.put(tabla.tabla(), tabla);
    }

    public Optional<TablaCatalogo> tabla(String nombre) {
        return Optional.ofNullable(tablas.get(nombre));
    }

    public List<TablaCatalogo> todas() {
        return List.copyOf(tablas.values());
    }

    /**
     * Descripcion para los prompts de la IA. Incluye, ademas del nombre y el
     * tipo, la etiqueta en lenguaje natural de cada columna (los ENUM llevan
     * sus valores validos dentro de la descripcion), para que el modelo no
     * tenga que adivinar el significado de los campos.
     */
    public String describir() {
        StringBuilder sb = new StringBuilder();
        for (TablaCatalogo t : tablas.values()) {
            sb.append("- ").append(t.tabla()).append(" (").append(t.etiqueta()).append("): ")
                    .append(t.descripcion()).append("\n");
            for (ColumnaCatalogo c : t.columnas()) {
                sb.append("    * ").append(c.nombre()).append(" [").append(c.tipo()).append("] ")
                        .append(c.etiqueta()).append("\n");
            }
        }
        return sb.toString();
    }
}
