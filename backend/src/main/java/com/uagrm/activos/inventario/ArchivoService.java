package com.uagrm.activos.inventario;

import com.uagrm.activos.tenant.TenantContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/** Almacenamiento seguro de fotos (HU-17): valida tipo, extension y path. */
@Service
public class ArchivoService {

    private static final Set<String> PERMITIDAS = Set.of("image/jpeg", "image/png", "image/webp");
    private static final long MAX_BYTES = 5L * 1024 * 1024;

    private final Path carpetaRaiz;

    public ArchivoService(@Value("${app.archivos.carpeta:/home/user/uploads}") String carpeta) {
        this.carpetaRaiz = Paths.get(carpeta);
    }

    /** Guarda la foto y devuelve la URL relativa con la que se recupera. */
    public String guardarFoto(MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se recibio ningun archivo");
        }
        if (archivo.getSize() > MAX_BYTES) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La foto supera el maximo de 5 MB");
        }
        String tipo = archivo.getContentType() == null ? "" : archivo.getContentType().toLowerCase(Locale.ROOT);
        if (!PERMITIDAS.contains(tipo)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Tipo de archivo no permitido. Use JPEG, PNG o WebP");
        }
        String extension = switch (tipo) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            default -> ".jpg";
        };
        try {
            Path carpetaEmpresa = carpetaRaiz.resolve("emp" + TenantContext.getEmpresaId());
            Files.createDirectories(carpetaEmpresa);
            String nombre = UUID.randomUUID() + extension;
            Path destino = carpetaEmpresa.resolve(nombre).normalize();
            if (!destino.startsWith(carpetaRaiz)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Ruta de archivo invalida");
            }
            Files.write(destino, archivo.getBytes());
            return "/api/inventario/archivos/emp" + TenantContext.getEmpresaId() + "/" + nombre;
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo guardar la foto: " + e.getMessage(), e);
        }
    }

    public Path resolver(String subRuta) {
        Path ruta = carpetaRaiz.resolve(subRuta).normalize();
        if (!ruta.startsWith(carpetaRaiz)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Ruta invalida");
        }
        if (!Files.exists(ruta)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Archivo no encontrado");
        }
        return ruta;
    }
}
