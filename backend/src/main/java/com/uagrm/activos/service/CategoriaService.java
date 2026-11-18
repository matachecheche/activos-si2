package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.domain.DepreciacionCalculadora;
import com.uagrm.activos.dto.CategoriaRequest;
import com.uagrm.activos.dto.CategoriaResponse;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.repository.CategoriaRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Objects;

/** HU-07: la vida util, el valor residual y el metodo se parametrizan por categoria. */
@Service
public class CategoriaService {

    private final CategoriaRepository categoriaRepository;
    private final DepreciacionService depreciacionService;

    public CategoriaService(CategoriaRepository categoriaRepository, DepreciacionService depreciacionService) {
        this.categoriaRepository = categoriaRepository;
        this.depreciacionService = depreciacionService;
    }

    @Transactional(readOnly = true)
    public List<CategoriaResponse> listar() {
        return categoriaRepository.findAll().stream()
                .sorted((a, b) -> a.getNombre().compareToIgnoreCase(b.getNombre()))
                .map(Mapeos::categoria)
                .toList();
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "CATEGORIA")
    public CategoriaResponse crear(CategoriaRequest req) {
        String nombre = req.nombre().trim();
        if (categoriaRepository.existsByNombreIgnoreCase(nombre)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe una categoría con ese nombre");
        }
        Categoria categoria = new Categoria();
        categoria.setNombre(nombre);
        aplicar(categoria, req);
        return Mapeos.categoria(categoriaRepository.save(categoria));
    }

    @Transactional
    @Auditable(accion = "EDITAR", entidad = "CATEGORIA", idExpresion = "#a0")
    public CategoriaResponse actualizar(Long id, CategoriaRequest req) {
        Categoria categoria = categoriaRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Categoría no encontrada"));
        String nombre = req.nombre().trim();
        categoriaRepository.findByNombre(nombre).filter(otra -> !otra.getId().equals(id)).ifPresent(otra -> {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe otra categoría con ese nombre");
        });

        Integer vidaAntes = categoria.getVidaUtil();
        BigDecimal pctAntes = categoria.getValorResidualPct();
        Boolean depreciableAntes = categoria.getDepreciable();
        String metodoAntes = categoria.getMetodoDepreciacion();

        categoria.setNombre(nombre);
        aplicar(categoria, req);
        categoria = categoriaRepository.save(categoria);

        boolean cambioParametros = !Objects.equals(vidaAntes, categoria.getVidaUtil())
                || !Objects.equals(depreciableAntes, categoria.getDepreciable())
                || !Objects.equals(metodoAntes, categoria.getMetodoDepreciacion())
                || (pctAntes == null ? categoria.getValorResidualPct() != null
                : categoria.getValorResidualPct() == null || pctAntes.compareTo(categoria.getValorResidualPct()) != 0);
        if (cambioParametros) {
            // las filas de depreciacion son datos derivados: se recalculan con los nuevos parametros
            depreciacionService.recalcularCategoria(categoria);
        }
        return Mapeos.categoria(categoria);
    }

    private void aplicar(Categoria categoria, CategoriaRequest req) {
        boolean depreciable = Boolean.TRUE.equals(req.depreciable());
        if (depreciable && (req.vidaUtil() == null || req.vidaUtil() <= 0)) {
            throw new IllegalArgumentException("Indique la vida útil (en años) de una categoría depreciable");
        }
        String metodo = req.metodoDepreciacion() == null || req.metodoDepreciacion().isBlank()
                ? DepreciacionCalculadora.LINEA_RECTA : req.metodoDepreciacion().trim().toUpperCase();
        DepreciacionCalculadora.estrategia(metodo); // valida que el metodo exista
        categoria.setDepreciable(depreciable);
        categoria.setVidaUtil(depreciable ? req.vidaUtil() : null);
        categoria.setMetodoDepreciacion(metodo);
        categoria.setValorResidualPct((req.valorResidualPct() == null ? BigDecimal.ZERO : req.valorResidualPct())
                .setScale(2, RoundingMode.HALF_UP));
    }
}
