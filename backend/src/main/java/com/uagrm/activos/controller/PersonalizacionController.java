package com.uagrm.activos.controller;

import com.uagrm.activos.model.ConfiguracionEmpresa;
import com.uagrm.activos.personalizacion.PersonalizacionService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

/** HU-15: marca y personalizacion de la empresa. */
@RestController
@RequestMapping("/api/configuracion")
public class PersonalizacionController {

    private final PersonalizacionService service;

    public PersonalizacionController(PersonalizacionService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("isAuthenticated()")
    public PersonalizacionService.VistaMarca ver() {
        return service.vista();
    }

    @PutMapping
    @PreAuthorize("hasAuthority('PERM_CONFIG_EMPRESA_EDITAR')")
    public ConfiguracionEmpresa guardar(@RequestBody Map<String, String> body) {
        return service.guardar(body.get("colorPrimario"), body.get("colorSecundario"),
                body.get("idioma"), body.get("menuConfig"));
    }

    @PostMapping("/logo")
    @PreAuthorize("hasAuthority('PERM_CONFIG_EMPRESA_EDITAR')")
    public PersonalizacionService.VistaMarca subirLogo(@RequestParam("logo") MultipartFile archivo) throws IOException {
        service.guardarLogo(archivo.getBytes(), archivo.getOriginalFilename(), archivo.getContentType());
        return service.vista();
    }

    @GetMapping("/logo")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<byte[]> logo() {
        ConfiguracionEmpresa c = service.obtener();
        if (c.getLogo() == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, c.getLogoTipo() == null ? MediaType.IMAGE_PNG_VALUE : c.getLogoTipo())
                .body(c.getLogo());
    }

    @DeleteMapping("/logo")
    @PreAuthorize("hasAuthority('PERM_CONFIG_EMPRESA_EDITAR')")
    public void borrarLogo() {
        service.eliminarLogo();
    }
}
