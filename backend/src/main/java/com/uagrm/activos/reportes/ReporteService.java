package com.uagrm.activos.reportes;

import com.lowagie.text.Document;
import com.lowagie.text.Element;
import com.lowagie.text.Font;
import com.lowagie.text.FontFactory;
import com.lowagie.text.PageSize;
import com.lowagie.text.Paragraph;
import com.lowagie.text.Phrase;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;
import com.uagrm.activos.ia.ConsultaEspec;
import com.uagrm.activos.ia.MotorConsultaSql;
import com.uagrm.activos.ia.ResultadoConsulta;
import com.uagrm.activos.tenant.TenantContext;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** HU-14: ejecucion de reportes con exportacion PDF/Excel y tablero BI. */
@Service
public class ReporteService {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    private final MotorConsultaSql motor;
    private final JdbcTemplate jdbcTemplate;

    public ReporteService(MotorConsultaSql motor, JdbcTemplate jdbcTemplate) {
        this.motor = motor;
        this.jdbcTemplate = jdbcTemplate;
    }

    public ResultadoConsulta consultar(ConsultaEspec espec) {
        return motor.ejecutar(espec);
    }

    public byte[] exportarPdf(ConsultaEspec espec, String titulo) {
        ResultadoConsulta r = motor.ejecutar(espec);
        try (ByteArrayOutputStream salida = new ByteArrayOutputStream()) {
            Document documento = new Document(PageSize.A4.rotate(), 20, 20, 30, 30);
            PdfWriter.getInstance(documento, salida);
            documento.open();
            Font tituloFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 16, new Color(15, 42, 92));
            Font normal = FontFactory.getFont(FontFactory.HELVETICA, 9);
            Font cabeceraFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.WHITE);

            documento.add(new Paragraph(titulo, tituloFont));
            documento.add(new Paragraph("Generado: " + LocalDateTime.now().format(FMT)
                    + "    Empresa ID: " + TenantContext.getEmpresaId(), normal));
            documento.add(new Paragraph(" "));

            PdfPTable tabla = new PdfPTable(r.columnas().size());
            tabla.setWidthPercentage(100);
            for (String col : r.columnas()) {
                PdfPCell celda = new PdfPCell(new Phrase(col, cabeceraFont));
                celda.setBackgroundColor(new Color(44, 92, 197));
                celda.setHorizontalAlignment(Element.ALIGN_CENTER);
                tabla.addCell(celda);
            }
            for (Map<String, Object> fila : r.filas()) {
                for (String col : r.columnas()) {
                    Object valor = fila.get(col);
                    tabla.addCell(new Phrase(valor == null ? "" : String.valueOf(valor), normal));
                }
            }
            documento.add(tabla);
            documento.add(new Paragraph(" "));
            documento.add(new Paragraph("Total de filas: " + r.filas().size(), normal));
            documento.close();
            return salida.toByteArray();
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo generar el PDF: " + e.getMessage(), e);
        }
    }

    public byte[] exportarExcel(ConsultaEspec espec) {
        ResultadoConsulta r = motor.ejecutar(espec);
        try (XSSFWorkbook libro = new XSSFWorkbook();
             ByteArrayOutputStream salida = new ByteArrayOutputStream()) {
            Sheet hoja = libro.createSheet(recortar(espec.entidad == null ? "reporte" : espec.entidad, 31));
            org.apache.poi.ss.usermodel.Font negrita = libro.createFont();
            negrita.setBold(true);
            CellStyle estiloCab = libro.createCellStyle();
            estiloCab.setFont(negrita);

            Row cabecera = hoja.createRow(0);
            for (int i = 0; i < r.columnas().size(); i++) {
                Cell celda = cabecera.createCell(i);
                celda.setCellValue(r.columnas().get(i));
                celda.setCellStyle(estiloCab);
            }
            int filaIdx = 1;
            for (Map<String, Object> fila : r.filas()) {
                Row filaExcel = hoja.createRow(filaIdx++);
                int colIdx = 0;
                for (String col : r.columnas()) {
                    Object valor = fila.get(col);
                    Cell celda = filaExcel.createCell(colIdx++);
                    if (valor instanceof Number n) {
                        celda.setCellValue(n.doubleValue());
                    } else if (valor != null) {
                        celda.setCellValue(String.valueOf(valor));
                    }
                }
            }
            for (int i = 0; i < r.columnas().size(); i++) {
                hoja.autoSizeColumn(i);
            }
            libro.write(salida);
            return salida.toByteArray();
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo generar el Excel: " + e.getMessage(), e);
        }
    }

    /** HU-14: KPIs y series para el tablero BI, siempre aislados por empresa. */
    public Map<String, Object> tableroBi() {
        Long empresaId = TenantContext.getEmpresaId();
        Map<String, Object> bi = new LinkedHashMap<>();
        bi.put("generado", LocalDateTime.now().format(FMT));

        bi.put("totalActivos", jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM activo WHERE empresa_id = ?", Long.class, empresaId));
        bi.put("valorTotalActivos", jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(valor),0) FROM activo WHERE empresa_id = ?",
                java.math.BigDecimal.class, empresaId));
        // Solo el ULTIMO periodo de cada activo: si se suman todas las filas
        // (una por mes) la depreciacion acumulada se cuenta muchas veces y el
        // tablero muestra cifras que no cuadran con el valor de los activos.
        bi.put("depreciacionAcumulada", jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(d.depreciacion_acumulada),0) FROM depreciacion_activo d "
                        + "WHERE d.empresa_id = ? AND d.periodo = ("
                        + "SELECT MAX(d2.periodo) FROM depreciacion_activo d2 "
                        + "WHERE d2.activo_id = d.activo_id AND d2.empresa_id = d.empresa_id)",
                java.math.BigDecimal.class, empresaId));
        bi.put("valorEnLibros", jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(d.valor_en_libros),0) FROM depreciacion_activo d "
                        + "WHERE d.empresa_id = ? AND d.periodo = ("
                        + "SELECT MAX(d2.periodo) FROM depreciacion_activo d2 "
                        + "WHERE d2.activo_id = d.activo_id AND d2.empresa_id = d.empresa_id)",
                java.math.BigDecimal.class, empresaId));
        bi.put("mantenimientosPendientes", jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM mantenimiento WHERE empresa_id = ? AND estado IN ('PROGRAMADO','EN_PROCESO')",
                Long.class, empresaId));
        bi.put("costoMantenimientos", jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(costo),0) FROM mantenimiento WHERE empresa_id = ?",
                java.math.BigDecimal.class, empresaId));

        bi.put("activosPorEstado", jdbcTemplate.queryForList(
                "SELECT estado, COUNT(*) AS cantidad FROM activo WHERE empresa_id = ? GROUP BY estado ORDER BY cantidad DESC",
                empresaId));
        bi.put("activosPorCategoria", jdbcTemplate.queryForList(
                "SELECT c.nombre AS categoria, COUNT(a.id) AS cantidad FROM activo a "
                        + "JOIN categoria c ON c.id = a.categoria_id "
                        + "WHERE a.empresa_id = ? GROUP BY c.nombre ORDER BY cantidad DESC",
                empresaId));
        bi.put("depreciacionMensual", jdbcTemplate.queryForList(
                "SELECT periodo, SUM(depreciacion_periodo) AS monto FROM depreciacion_activo "
                        + "WHERE empresa_id = ? GROUP BY periodo ORDER BY periodo DESC LIMIT 12",
                empresaId));
        bi.put("presupuestoPorGestion", jdbcTemplate.queryForList(
                "SELECT gestion, SUM(monto_aprobado) AS aprobado FROM presupuesto "
                        + "WHERE empresa_id = ? GROUP BY gestion ORDER BY gestion DESC LIMIT 6",
                empresaId));
        return bi;
    }

    private String recortar(String texto, int max) {
        return texto.length() <= max ? texto : texto.substring(0, max);
    }
}
