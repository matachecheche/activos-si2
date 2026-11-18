package com.uagrm.activos.controller;

import com.uagrm.activos.dto.VerificacionRequest;
import com.uagrm.activos.inventario.ArchivoService;
import com.uagrm.activos.inventario.VerificacionInventarioService;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.VerificacionInventario;
import jakarta.validation.Valid;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.file.Path;
import java.util.Map;

/** HU-17: verificacion de inventario desde el movil, con fotos y GPS. */
@RestController
@RequestMapping("/api/inventario")
public class InventarioController {

    private final VerificacionInventarioService service;
    private final ArchivoService archivoService;

    public InventarioController(VerificacionInventarioService service, ArchivoService archivoService) {
        this.service = service;
        this.archivoService = archivoService;
    }

    @PostMapping("/verificaciones")
    @PreAuthorize("hasAuthority('PERM_INVENTARIO_VERIFICAR')")
    public VerificacionInventario verificar(@Valid @RequestBody VerificacionRequest req) {
        return service.registrar(req.getActivoId(), req.getResultado(), req.getLatitud(),
                req.getLongitud(), req.getPrecisionM(), req.getObservacion(), req.getFotoUrl());
    }

    @GetMapping("/verificaciones")
    @PreAuthorize("hasAuthority('PERM_INVENTARIO_LEER')")
    public Page<VerificacionInventario> listar(@RequestParam(defaultValue = "0") int pagina,
                                               @RequestParam(defaultValue = "20") int tamano) {
        return service.listar(pagina, tamano);
    }

    @GetMapping("/estadisticas")
    @PreAuthorize("hasAuthority('PERM_INVENTARIO_LEER')")
    public Map<String, Object> estadisticas() {
        return service.estadisticas();
    }

    /** Sube una foto (verificacion o evidencia de activo) y devuelve su URL relativa. */
    @PostMapping("/foto")
    @PreAuthorize("hasAuthority('PERM_INVENTARIO_VERIFICAR')")
    public Map<String, String> subirFoto(@RequestParam("foto") MultipartFile foto) {
        return Map.of("fotoUrl", archivoService.guardarFoto(foto));
    }

    @PostMapping("/activos/{id}/foto")
    @PreAuthorize("hasAuthority('PERM_INVENTARIO_VERIFICAR')")
    public Activo fotoDeActivo(@PathVariable Long id, @RequestParam("foto") MultipartFile foto) {
        String url = archivoService.guardarFoto(foto);
        return service.asignarFotoActivo(id, url);
    }

    /** Recupera las fotos por la URL relativa devuelta al subirlas. */
    @GetMapping("/archivos/**")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Resource> servir(jakarta.servlet.http.HttpServletRequest request) {
        String uri = request.getRequestURI();
        String subRuta = uri.substring(uri.indexOf("/archivos/") + "/archivos/".length());
        Path ruta = archivoService.resolver(java.net.URLDecoder.decode(subRuta, java.nio.charset.StandardCharsets.UTF_8));
        String nombre = ruta.getFileName().toString().toLowerCase();
        MediaType tipo = nombre.endsWith(".png") ? MediaType.IMAGE_PNG
                : nombre.endsWith(".webp") ? MediaType.parseMediaType("image/webp")
                : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_TYPE, tipo.toString())
                .body(new FileSystemResource(ruta));
    }
}
