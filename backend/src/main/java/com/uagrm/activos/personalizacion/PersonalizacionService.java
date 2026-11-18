package com.uagrm.activos.personalizacion;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.model.ConfiguracionEmpresa;
import com.uagrm.activos.repository.ConfiguracionEmpresaRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.regex.Pattern;

/** HU-15: colores, logotipo, idioma y disposicion del menu por empresa. */
@Service
public class PersonalizacionService {

    private static final Pattern HEX = Pattern.compile("^#[0-9a-fA-F]{6}$");
    private static final List<String> IDIOMAS = List.of("es", "en");
    private static final List<String> MENUS = List.of("LATERAL", "SUPERIOR");
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final ConfiguracionEmpresaRepository repo;
    private final AuditoriaService auditoriaService;
    private final long logoMaxBytes;

    public PersonalizacionService(ConfiguracionEmpresaRepository repo,
                                  AuditoriaService auditoriaService,
                                  @Value("${app.marca.logo-max-bytes:1048576}") long logoMaxBytes) {
        this.repo = repo;
        this.auditoriaService = auditoriaService;
        this.logoMaxBytes = logoMaxBytes;
    }

    @Transactional(readOnly = true)
    public ConfiguracionEmpresa obtener() {
        return repo.findByEmpresaId(TenantContext.getEmpresaId())
                .orElseGet(() -> ConfiguracionEmpresa.builder()
                        .empresaId(TenantContext.getEmpresaId()).menuConfig("[]").build());
    }

    /** Vista sin el binario del logo (la grilla no debe cargar imagenes en base64). */
    @Transactional(readOnly = true)
    public VistaMarca vista() {
        ConfiguracionEmpresa c = obtener();
        return new VistaMarca(c.getColorPrimario(), c.getColorSecundario(), c.getIdioma(),
                c.getMenuConfig(), c.getLogo() != null, c.getLogoNombre(), c.getLogoTipo());
    }

    @Transactional
    public ConfiguracionEmpresa guardar(String colorPrimario, String colorSecundario,
                                        String idioma, String menuConfig) {
        validarColor(colorPrimario);
        validarColor(colorSecundario);
        if (idioma != null && !IDIOMAS.contains(idioma)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Idioma no soportado (use es o en)");
        }
        validarMenu(menuConfig);
        ConfiguracionEmpresa c = obtener();
        c.setColorPrimario(colorPrimario);
        c.setColorSecundario(colorSecundario);
        if (idioma != null) {
            c.setIdioma(idioma);
        }
        if (menuConfig != null) {
            c.setMenuConfig(menuConfig);
        }
        ConfiguracionEmpresa guardado = repo.save(c);
        auditoriaService.registrar("PERSONALIZAR", "CONFIGURACION_EMPRESA",
                String.valueOf(guardado.getId()), "Actualizacion de colores/idioma/menu");
        return guardado;
    }

    @Transactional
    public ConfiguracionEmpresa guardarLogo(byte[] bytes, String nombre, String contentType) {
        if (bytes == null || bytes.length == 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El archivo del logo esta vacio");
        }
        if (bytes.length > logoMaxBytes) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "El logo supera el tamano maximo de " + logoMaxBytes + " bytes (1 MB)");
        }
        if (contentType == null || !contentType.toLowerCase().startsWith("image/")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El logo debe ser una imagen");
        }
        ConfiguracionEmpresa c = obtener();
        c.setLogo(bytes);
        c.setLogoNombre(nombre);
        c.setLogoTipo(contentType);
        ConfiguracionEmpresa guardado = repo.save(c);
        auditoriaService.registrar("SUBIR_LOGO", "CONFIGURACION_EMPRESA",
                String.valueOf(guardado.getId()), "Logo " + nombre + " (" + bytes.length + " bytes)");
        return guardado;
    }

    @Transactional
    public void eliminarLogo() {
        ConfiguracionEmpresa c = obtener();
        c.setLogo(null);
        c.setLogoNombre(null);
        c.setLogoTipo(null);
        repo.save(c);
        auditoriaService.registrar("ELIMINAR_LOGO", "CONFIGURACION_EMPRESA",
                String.valueOf(c.getId()), "Logo eliminado");
    }

    private void validarColor(String color) {
        if (color == null || !HEX.matcher(color).matches()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Color invalido, use formato hexadecimal #RRGGBB");
        }
    }

    private void validarMenu(String menuConfig) {
        if (menuConfig == null) {
            return;
        }
        try {
            var valor = MAPPER.readTree(menuConfig);
            if (!valor.isArray()) {
                throw new IllegalArgumentException("debe ser un arreglo");
            }
            for (var item : valor) {
                String posicion = item.path("posicion").asText("");
                if (!MENUS.contains(posicion)) {
                    throw new IllegalArgumentException("posicion de menu invalida: " + posicion);
                }
            }
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La configuracion del menu no es valida: " + e.getMessage());
        }
    }

    public record VistaMarca(String colorPrimario, String colorSecundario, String idioma,
                             String menuConfig, boolean tieneLogo, String logoNombre, String logoTipo) {
    }
}
