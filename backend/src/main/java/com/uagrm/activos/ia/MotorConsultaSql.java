package com.uagrm.activos.ia;

import com.uagrm.activos.tenant.TenantContext;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * HU-14: convierte una ConsultaEspec validada en SQL parametrizado.
 * Reglas de seguridad (14.12.2): solo SELECT; tablas y columnas de lista
 * blanca; operadores permitidos; valores siempre enlazados como parametros
 * (nunca concatenados); scope obligatorio por empresa_id; limite acotado.
 */
@Component
public class MotorConsultaSql {

    private static final Set<String> AGREGACIONES = Set.of("COUNT", "SUM", "AVG", "MIN", "MAX");
    private static final int MAX_FILAS = 500;

    private final CatalogoSql catalogo;
    private final JdbcTemplate jdbcTemplate;

    public MotorConsultaSql(CatalogoSql catalogo, JdbcTemplate jdbcTemplate) {
        this.catalogo = catalogo;
        this.jdbcTemplate = jdbcTemplate;
    }

    public ResultadoConsulta ejecutar(ConsultaEspec espec) {
        TablaCatalogo tabla = catalogo.tabla(espec.entidad == null ? "" : espec.entidad.toLowerCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Entidad no permitida o desconocida: " + espec.entidad));
        var columnasTabla = tabla.mapaColumnas();

        StringBuilder sql = new StringBuilder("SELECT ");
        List<String> select = construirSelect(tabla, columnasTabla, espec);
        sql.append(String.join(", ", select));
        sql.append(" FROM ").append(tabla.tabla());

        List<Object> parametros = new ArrayList<>();
        List<String> where = new ArrayList<>();
        if (!TenantContext.esSuperAdmin()) {
            Long empresaId = TenantContext.getEmpresaId();
            if (empresaId == null) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Sin empresa en el contexto");
            }
            where.add("empresa_id = ?");
            parametros.add(empresaId);
        }
        if (espec.filtros != null) {
            for (ConsultaEspec.FiltroEspec f : espec.filtros) {
                if (f == null || f.campo == null) {
                    continue;
                }
                ColumnaCatalogo col = columnasTabla.get(f.campo.toLowerCase());
                if (col == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "Columna no permitida: " + f.campo);
                }
                String op = f.operador == null ? "=" : f.operador.trim().toUpperCase();
                if (!CatalogoSql.OPERADORES.contains(op)) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Operador no permitido: " + f.operador);
                }
                if (op.equals("IS NULL") || op.equals("IS NOT NULL")) {
                    where.add(col.nombre() + " " + op);
                } else if (op.equals("IN")) {
                    List<Object> vals = f.valores == null ? List.of() : f.valores;
                    if (vals.isEmpty()) {
                        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "IN requiere valores");
                    }
                    where.add(col.nombre() + " IN (" + String.join(",", vals.stream().map(v -> "?").toList()) + ")");
                    vals.forEach(v -> parametros.add(validarValor(col, v)));
                } else if (op.equals("BETWEEN")) {
                    where.add(col.nombre() + " BETWEEN ? AND ?");
                    parametros.add(validarValor(col, f.valor));
                    parametros.add(validarValor(col, f.valorHasta));
                } else {
                    where.add(col.nombre() + " " + op + " ?");
                    parametros.add(validarValor(col, op.contains("LIKE") ? "%" + String.valueOf(f.valor) + "%" : f.valor));
                }
            }
        }
        if (!where.isEmpty()) {
            sql.append(" WHERE ").append(String.join(" AND ", where));
        }

        List<String> group = new ArrayList<>();
        if (espec.agregacion != null && espec.agregacion.agruparPor != null) {
            for (String g : espec.agregacion.agruparPor) {
                if (!columnasTabla.containsKey(g.toLowerCase())) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Columna de agrupacion no permitida: " + g);
                }
                group.add(g.toLowerCase());
            }
            if (!group.isEmpty()) {
                sql.append(" GROUP BY ").append(String.join(", ", group));
            }
        }

        if (espec.orden != null) {
            List<String> ordenes = new ArrayList<>();
            for (ConsultaEspec.OrdenEspec o : espec.orden) {
                if (o == null || o.campo == null) {
                    continue;
                }
                if (!columnasTabla.containsKey(o.campo.toLowerCase())) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Columna de orden no permitida: " + o.campo);
                }
                String dir = "DESC".equalsIgnoreCase(o.direccion) ? "DESC" : "ASC";
                ordenes.add(o.campo.toLowerCase() + " " + dir);
            }
            if (!ordenes.isEmpty()) {
                sql.append(" ORDER BY ").append(String.join(", ", ordenes));
            }
        }

        int limite = Math.min(espec.limite == null ? 100 : espec.limite, MAX_FILAS);
        sql.append(" LIMIT ").append(limite);

        List<java.util.Map<String, Object>> filas = jdbcTemplate.queryForList(sql.toString(), parametros.toArray());
        List<String> cabeceras = filas.isEmpty() ? List.copyOf(extraerCabeceras(select, group))
                : List.copyOf(filas.get(0).keySet());
        return new ResultadoConsulta(sql.toString(), cabeceras, filas);
    }

    private List<String> construirSelect(TablaCatalogo tabla,
                                         java.util.Map<String, ColumnaCatalogo> columnas,
                                         ConsultaEspec espec) {
        if (espec.agregacion != null) {
            var a = espec.agregacion;
            String fn = a.funcion == null ? "" : a.funcion.trim().toUpperCase();
            if (!AGREGACIONES.contains(fn)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Funcion de agregacion no permitida: " + a.funcion);
            }
            List<String> partes = new ArrayList<>();
            if ("*".equals(a.campo)) {
                if (!"COUNT".equals(fn)) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "* solo es valido con COUNT");
                }
                partes.add("COUNT(*) AS total");
            } else {
                ColumnaCatalogo c = columnas.get(a.campo == null ? "" : a.campo.toLowerCase());
                if (c == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Columna de agregacion no permitida: " + a.campo);
                }
                if (c.tipo() != TipoColumna.NUMERO && !"COUNT".equals(fn)) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, fn + " solo aplica a columnas numericas");
                }
                partes.add(fn + "(" + c.nombre() + ") AS " + fn.toLowerCase() + "_" + c.nombre());
            }
            if (a.agruparPor != null) {
                for (String g : a.agruparPor) {
                    if (columnas.containsKey(g.toLowerCase())) {
                        partes.add(g.toLowerCase());
                    }
                }
            }
            return partes;
        }

        if (espec.columnas == null || espec.columnas.isEmpty()) {
            return tabla.columnas().stream().map(ColumnaCatalogo::nombre).toList();
        }
        Set<String> unicas = new LinkedHashSet<>();
        for (String c : espec.columnas) {
            if (!columnas.containsKey(c.toLowerCase())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Columna no permitida: " + c);
            }
            unicas.add(c.toLowerCase());
        }
        return List.copyOf(unicas);
    }

    private Object validarValor(ColumnaCatalogo col, Object valor) {
        if (valor == null) {
            return null;
        }
        switch (col.tipo()) {
            case NUMERO -> {
                if (valor instanceof Number n) {
                    return n;
                }
                try {
                    String txt = String.valueOf(valor).trim();
                    return txt.contains(".") ? Double.parseDouble(txt) : Long.parseLong(txt);
                } catch (NumberFormatException e) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "Valor numerico invalido para " + col.nombre());
                }
            }
            case BOOLEANO -> {
                if (valor instanceof Boolean b) {
                    return b;
                }
                String txt = String.valueOf(valor).trim().toLowerCase();
                if (!txt.equals("true") && !txt.equals("false")) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Valor booleano invalido para " + col.nombre());
                }
                return Boolean.parseBoolean(txt);
            }
            default -> {
                String txt = String.valueOf(valor);
                if (txt.length() > 500) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Valor demasiado largo para " + col.nombre());
                }
                return txt;
            }
        }
    }

    private Set<String> extraerCabeceras(List<String> select, List<String> group) {
        Set<String> cabeceras = new LinkedHashSet<>();
        for (String s : select) {
            int as = s.toUpperCase().indexOf(" AS ");
            cabeceras.add(as >= 0 ? s.substring(as + 4) : s);
        }
        return cabeceras;
    }
}
