package com.uagrm.activos.controller;

import com.uagrm.activos.ia.ConsultaEspec;
import com.uagrm.activos.ia.ResultadoConsulta;
import com.uagrm.activos.reportes.ReporteService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/** HU-14: reportes dinamicos, exportaciones y tablero BI. */
@RestController
@RequestMapping("/api/reportes")
public class ReporteController {

    private final ReporteService reporteService;

    public ReporteController(ReporteService reporteService) {
        this.reporteService = reporteService;
    }

    @PostMapping("/consultar")
    @PreAuthorize("hasAuthority('PERM_REPORTES_LEER')")
    public ResultadoConsulta consultar(@RequestBody ConsultaEspec espec) {
        return reporteService.consultar(espec);
    }

    @PostMapping("/exportar/pdf")
    @PreAuthorize("hasAuthority('PERM_REPORTES_LEER')")
    public ResponseEntity<byte[]> pdf(@RequestBody ConsultaEspec espec,
                                      @RequestParam(defaultValue = "Reporte de activos") String titulo) {
        byte[] pdf = reporteService.exportarPdf(espec, titulo);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, "application/pdf")
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename*=UTF-8''" + URLEncoder.encode(titulo + ".pdf", StandardCharsets.UTF_8))
                .body(pdf);
    }

    @PostMapping("/exportar/excel")
    @PreAuthorize("hasAuthority('PERM_REPORTES_LEER')")
    public ResponseEntity<byte[]> excel(@RequestBody ConsultaEspec espec) {
        byte[] xlsx = reporteService.exportarExcel(espec);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet").toString())
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=reporte.xlsx")
                .body(xlsx);
    }

    @GetMapping("/bi")
    @PreAuthorize("hasAuthority('PERM_REPORTES_LEER')")
    public Map<String, Object> bi() {
        return reporteService.tableroBi();
    }
}
