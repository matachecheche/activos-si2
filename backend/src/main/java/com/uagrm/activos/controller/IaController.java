package com.uagrm.activos.controller;

import com.uagrm.activos.ia.*;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/** HU-14: asistente de consultas en lenguaje natural y constructor de consultas. */
@RestController
@RequestMapping("/api/ia")
public class IaController {

    private final IaService iaService;
    private final MotorConsultaSql motor;
    private final CatalogoSql catalogo;
    private final IaConfigLoader configLoader;

    public IaController(IaService iaService, MotorConsultaSql motor, CatalogoSql catalogo,
                        IaConfigLoader configLoader) {
        this.iaService = iaService;
        this.motor = motor;
        this.catalogo = catalogo;
        this.configLoader = configLoader;
    }

    /** Diagnostico: permite verificar en el navegador si las claves llegaron al backend. */
    @GetMapping("/estado")
    @PreAuthorize("hasAuthority('PERM_IA_CONSULTAR') or hasAuthority('PERM_REPORTES_LEER')")
    public Map<String, Object> estado() {
        return configLoader.estado();
    }

    @PostMapping("/consulta")
    @PreAuthorize("hasAuthority('PERM_IA_CONSULTAR')")
    public RespuestaIa consulta(@Valid @RequestBody PreguntaIaRequest request) {
        return iaService.preguntar(request.getPregunta(), request.getHistorial());
    }

    /** Prueba en vivo contra Groq y Gemini y devuelve el detalle tecnico de cada intento. */
    @PostMapping("/probar")
    @PreAuthorize("hasAuthority('PERM_IA_CONSULTAR') or hasAuthority('PERM_REPORTES_LEER')")
    public java.util.List<java.util.Map<String, Object>> probar() {
        return iaService.probarConexion();
    }

    /** Ejecuta una especificacion construida a mano (modo guiado / sin clave de IA). */
    @PostMapping("/ejecutar")
    @PreAuthorize("hasAuthority('PERM_IA_CONSULTAR')")
    public ResultadoConsulta ejecutar(@RequestBody ConsultaEspec espec) {
        return motor.ejecutar(espec);
    }

    @GetMapping("/catalogo")
    @PreAuthorize("hasAuthority('PERM_IA_CONSULTAR') or hasAuthority('PERM_REPORTES_LEER')")
    public Object catalogo() {
        return catalogo.todas();
    }
}
