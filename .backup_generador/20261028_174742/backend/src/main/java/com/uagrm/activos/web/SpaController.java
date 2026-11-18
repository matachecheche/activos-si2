package com.uagrm.activos.web;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Agregado por desplegar_azure.py.
 * Sirve la aplicacion Angular (SPA) alojada en src/main/resources/static.
 * Las rutas del frontend se reenvian a index.html; la API (/api/**) y los
 * archivos con extension (.js, .css, .png...) no se tocan.
 */
@Controller
public class SpaController {

    @GetMapping({
        "/",
        "/{seg:(?!api)[a-zA-Z0-9-]+}",
        "/{seg:(?!api)[a-zA-Z0-9-]+}/**"
    })
    public String forwardAngular() {
        return "forward:/index.html";
    }
}
