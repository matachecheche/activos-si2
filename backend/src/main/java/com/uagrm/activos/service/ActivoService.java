package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.dto.ActivoRequest;
import com.uagrm.activos.dto.ActivoResponse;
import com.uagrm.activos.dto.CambioEstadoRequest;
import com.uagrm.activos.dto.HistorialEstadoResponse;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.model.DepreciacionActivo;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.AsignacionRepository;
import com.uagrm.activos.repository.CategoriaRepository;
import com.uagrm.activos.repository.DepreciacionRepository;
import com.uagrm.activos.repository.EjecucionRepository;
import com.uagrm.activos.repository.HistorialEstadoRepository;
import com.uagrm.activos.repository.MantenimientoRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.uagrm.activos.saas.PlanLimitsService;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Year;
import java.time.YearMonth;
import java.util.Comparator;
import java.util.List;

/** HU-02 (registro y edicion), HU-05 (busqueda por codigo) y HU-06 (estado). */
@Service
public class ActivoService {

    private final ActivoRepository activoRepository;
    private final CategoriaRepository categoriaRepository;
    private final AsignacionRepository asignacionRepository;
    private final HistorialEstadoRepository historialRepository;
    private final MantenimientoRepository mantenimientoRepository;
    private final EjecucionRepository ejecucionRepository;
    private final DepreciacionRepository depreciacionRepository;
    private final DepreciacionService depreciacionService;
    private final EstadoActivoService estadoActivoService;
    private final SesionService sesionService;

    @Autowired
    private PlanLimitsService planLimitsService;

    public ActivoService(ActivoRepository activoRepository,
                         CategoriaRepository categoriaRepository,
                         AsignacionRepository asignacionRepository,
                         HistorialEstadoRepository historialRepository,
                         MantenimientoRepository mantenimientoRepository,
                         EjecucionRepository ejecucionRepository,
                         DepreciacionRepository depreciacionRepository,
                         DepreciacionService depreciacionService,
                         EstadoActivoService estadoActivoService,
                         SesionService sesionService) {
        this.activoRepository = activoRepository;
        this.categoriaRepository = categoriaRepository;
        this.asignacionRepository = asignacionRepository;
        this.historialRepository = historialRepository;
        this.mantenimientoRepository = mantenimientoRepository;
        this.ejecucionRepository = ejecucionRepository;
        this.depreciacionRepository = depreciacionRepository;
        this.depreciacionService = depreciacionService;
        this.estadoActivoService = estadoActivoService;
        this.sesionService = sesionService;
    }

    @Transactional(readOnly = true)
    public List<ActivoResponse> listar() {
        return activoRepository.findAll().stream()
                .sorted(Comparator.comparing(Activo::getCodigo))
                .map(a -> Mapeos.activo(a, null))
                .toList();
    }

    @Transactional(readOnly = true)
    public ActivoResponse detalle(Long id) {
        Activo activo = entidad(id);
        return Mapeos.activo(activo, !tieneMovimientos(activo));
    }

    /** HU-05: el QR codifica el codigo unico; al buscar ese codigo se muestra la ficha. */
    @Transactional(readOnly = true)
    public ActivoResponse porCodigo(String codigo) {
        Activo activo = activoRepository.findByCodigo(codigo == null ? "" : codigo.trim())
                .orElseThrow(() -> new IllegalArgumentException("No existe un activo con el código " + codigo));
        return Mapeos.activo(activo, !tieneMovimientos(activo));
    }

    @Transactional
    @Auditable(accion = "CREAR", entidad = "ACTIVO")
    public ActivoResponse registrar(ActivoRequest req) {
        planLimitsService.verificarLimiteActivos(); // HU-11: limite del plan
        Categoria categoria = categoria(req.categoriaId());
        BigDecimal valor = req.valor().setScale(2, RoundingMode.HALF_UP);
        BigDecimal residual = residual(req.valorResidual(), valor, categoria);

        Activo activo = Activo.builder()
                .codigo(generarCodigo())
                .nombre(req.nombre().trim())
                .categoria(categoria)
                .valor(valor)
                .valorResidual(residual)
                .fechaAdquisicion(req.fechaAdquisicion())
                .fechaInicioDepreciacion(req.fechaInicioDepreciacion() != null ? req.fechaInicioDepreciacion() : req.fechaAdquisicion())
                .proveedor(vacioANulo(req.proveedor()))
                .observaciones(vacioANulo(req.observaciones()))
                .estado(EstadoActivo.DISPONIBLE)
                .build();
        activo = activoRepository.save(activo);
        depreciacionService.calcularActivo(activo, YearMonth.now());
        return Mapeos.activo(activo, true);
    }

    @Transactional
    @Auditable(accion = "EDITAR", entidad = "ACTIVO", idExpresion = "#a0")
    public ActivoResponse actualizar(Long id, ActivoRequest req) {
        Activo activo = entidad(id);
        if (tieneMovimientos(activo)) {
            throw new IllegalStateException("No se puede editar un activo que ya tiene movimientos asociados");
        }
        Categoria categoria = categoria(req.categoriaId());
        BigDecimal valor = req.valor().setScale(2, RoundingMode.HALF_UP);

        activo.setNombre(req.nombre().trim());
        activo.setCategoria(categoria);
        activo.setValor(valor);
        activo.setValorResidual(residual(req.valorResidual(), valor, categoria));
        activo.setFechaAdquisicion(req.fechaAdquisicion());
        activo.setFechaInicioDepreciacion(req.fechaInicioDepreciacion() != null ? req.fechaInicioDepreciacion() : req.fechaAdquisicion());
        activo.setProveedor(vacioANulo(req.proveedor()));
        activo.setObservaciones(vacioANulo(req.observaciones()));
        activo = activoRepository.save(activo);

        // la depreciacion depende de estos datos: se recalcula desde cero
        List<DepreciacionActivo> filas = depreciacionRepository.findByActivoOrderByPeriodoAsc(activo);
        depreciacionRepository.deleteAll(filas);
        depreciacionRepository.flush();
        depreciacionService.calcularActivo(activo, YearMonth.now());
        return Mapeos.activo(activo, true);
    }

    @Transactional
    @Auditable(accion = "CAMBIO_ESTADO", entidad = "ACTIVO", idExpresion = "#a0")
    public ActivoResponse cambiarEstado(Long id, CambioEstadoRequest req) {
        Activo activo = entidad(id);
        estadoActivoService.cambiarManual(activo, req.estado(), req.motivo(), sesionService.usuarioActual(),
                sesionService.esAdministrador(), sesionService.tienePermiso("ACTIVOS_ELIMINAR"));
        return Mapeos.activo(activo, !tieneMovimientos(activo));
    }

    @Transactional(readOnly = true)
    public List<HistorialEstadoResponse> historialEstados(Long id) {
        return estadoActivoService.historial(entidad(id));
    }

    public Activo entidad(Long id) {
        return activoRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
    }

    /** Movimientos: asignaciones, cambios de estado, mantenimientos o ejecuciones presupuestarias. */
    private boolean tieneMovimientos(Activo activo) {
        return asignacionRepository.existsByActivo(activo)
                || historialRepository.existsByActivo(activo)
                || mantenimientoRepository.existsByActivo(activo)
                || ejecucionRepository.existsByActivo(activo);
    }

    private Categoria categoria(Long id) {
        return categoriaRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Categoría no encontrada"));
    }

    private BigDecimal residual(BigDecimal indicado, BigDecimal valor, Categoria categoria) {
        BigDecimal residual;
        if (indicado != null) {
            residual = indicado.setScale(2, RoundingMode.HALF_UP);
        } else {
            BigDecimal pct = categoria.getValorResidualPct() == null ? BigDecimal.ZERO : categoria.getValorResidualPct();
            residual = valor.multiply(pct).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        }
        if (residual.compareTo(valor) > 0) {
            throw new IllegalArgumentException("El valor residual no puede superar el valor de adquisición");
        }
        return residual;
    }

    private String vacioANulo(String texto) {
        return texto == null || texto.isBlank() ? null : texto.trim();
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
