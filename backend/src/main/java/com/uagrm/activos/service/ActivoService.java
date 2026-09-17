package com.uagrm.activos.service;

import com.uagrm.activos.dto.ActivoRequest;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.CategoriaRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Year;
import java.util.List;

// HU-02: Registrar activos fijos por categoria
@Service
public class ActivoService {

    private final ActivoRepository activoRepository;
    private final CategoriaRepository categoriaRepository;

    public ActivoService(ActivoRepository activoRepository, CategoriaRepository categoriaRepository) {
        this.activoRepository = activoRepository;
        this.categoriaRepository = categoriaRepository;
    }

    public List<Activo> listar() {
        return activoRepository.findAll();
    }

    public Activo obtener(Long id) {
        return activoRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
    }

    public Activo registrar(ActivoRequest req) {
        if (req.getValor() == null || req.getValor().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("El valor de adquisicion no puede ser negativo ni cero");
        }
        Categoria categoria = categoriaRepository.findById(req.getCategoriaId())
                .orElseThrow(() -> new IllegalArgumentException("Categoria no encontrada"));

        Activo activo = Activo.builder()
                .codigo(generarCodigo())
                .nombre(req.getNombre())
                .categoria(categoria)
                .valor(req.getValor())
                .fechaAdquisicion(req.getFechaAdquisicion())
                .proveedor(req.getProveedor())
                .observaciones(req.getObservaciones())
                .estado(EstadoActivo.SIN_ASIGNAR)
                .build();

        return activoRepository.save(activo);
    }

    public Activo actualizar(Long id, ActivoRequest req) {
        Activo activo = obtener(id);
        if (activo.getResponsable() != null) {
            throw new IllegalStateException("No se puede editar un activo que ya tiene movimientos asociados");
        }
        Categoria categoria = categoriaRepository.findById(req.getCategoriaId())
                .orElseThrow(() -> new IllegalArgumentException("Categoria no encontrada"));

        activo.setNombre(req.getNombre());
        activo.setCategoria(categoria);
        activo.setValor(req.getValor());
        activo.setFechaAdquisicion(req.getFechaAdquisicion());
        activo.setProveedor(req.getProveedor());
        activo.setObservaciones(req.getObservaciones());
        return activoRepository.save(activo);
    }

    private String generarCodigo() {
        String anio = String.valueOf(Year.now().getValue());
        long consecutivo = activoRepository.count() + 1;
        String codigo;
        do {
            codigo = "ACT-" + anio + "-" + String.format("%04d", consecutivo);
            consecutivo++;
        } while (activoRepository.existsByCodigo(codigo));
        return codigo;
    }
}
