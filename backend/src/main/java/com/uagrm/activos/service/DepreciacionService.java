package com.uagrm.activos.service;

import com.uagrm.activos.auditoria.Auditable;

import com.uagrm.activos.domain.DepreciacionCalculadora;
import com.uagrm.activos.dto.CalculoDepreciacionResponse;
import com.uagrm.activos.dto.DepreciacionActivoResponse;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.model.DepreciacionActivo;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.model.Empresa;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.DepreciacionRepository;
import com.uagrm.activos.repository.EmpresaRepository;
import com.uagrm.activos.tenant.TenantContext;
import com.uagrm.activos.tenant.TenantResolver;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * HU-07: depreciacion por linea recta. El calculo es idempotente: la combinacion activo-periodo
 * es unica, por lo que ejecutarlo varias veces no genera registros duplicados.
 */
@Service
public class DepreciacionService {

    private final ActivoRepository activoRepository;
    private final DepreciacionRepository depreciacionRepository;
    private final EmpresaRepository empresaRepository;
    private final TransactionTemplate transaccionNueva;

    public DepreciacionService(ActivoRepository activoRepository, DepreciacionRepository depreciacionRepository,
                                EmpresaRepository empresaRepository,
                                PlatformTransactionManager transactionManager) {
        this.activoRepository = activoRepository;
        this.depreciacionRepository = depreciacionRepository;
        this.empresaRepository = empresaRepository;
        this.transaccionNueva = new TransactionTemplate(transactionManager);
        this.transaccionNueva.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    /** Parametros efectivos de un activo (los de su categoria, el valor y el residual). */
    private record Parametros(boolean depreciable, BigDecimal valor, BigDecimal residual, int meses,
                              YearMonth inicio, DepreciacionCalculadora.Estrategia estrategia) {
    }

    private Parametros parametros(Activo activo) {
        Categoria categoria = activo.getCategoria();
        BigDecimal valor = activo.getValor().setScale(2, RoundingMode.HALF_UP);
        BigDecimal residual;
        if (activo.getValorResidual() != null) {
            residual = activo.getValorResidual();
        } else {
            BigDecimal pct = categoria.getValorResidualPct() == null ? BigDecimal.ZERO : categoria.getValorResidualPct();
            residual = valor.multiply(pct).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        }
        residual = residual.max(BigDecimal.ZERO).min(valor).setScale(2, RoundingMode.HALF_UP);
        LocalDate fechaInicio = activo.getFechaInicioDepreciacion() != null
                ? activo.getFechaInicioDepreciacion() : activo.getFechaAdquisicion();
        boolean depreciable = categoria.esDepreciable();
        int meses = depreciable ? categoria.getVidaUtil() * 12 : 0;
        return new Parametros(depreciable, valor, residual, meses, YearMonth.from(fechaInicio),
                DepreciacionCalculadora.estrategia(categoria.getMetodoDepreciacion()));
    }

    /** Genera los periodos que faltan hasta {@code hasta}. Devuelve cuantos periodos nuevos registro. */
    @Transactional
    public int calcularActivo(Activo activo, YearMonth hasta) {
        Parametros p = parametros(activo);
        if (!p.depreciable()) {
            return 0;
        }
        YearMonth tope = hasta;
        if (activo.getEstado() == EstadoActivo.DADO_DE_BAJA && activo.getFechaBaja() != null) {
            // un activo dado de baja deja de depreciarse desde el mes de su baja
            YearMonth antesDeLaBaja = YearMonth.from(activo.getFechaBaja()).minusMonths(1);
            if (antesDeLaBaja.isBefore(tope)) {
                tope = antesDeLaBaja;
            }
        }
        List<DepreciacionCalculadora.Fila> filas = p.estrategia().calcular(p.valor(), p.residual(), p.meses(), p.inicio(), tope);
        if (filas.isEmpty()) {
            return 0;
        }
        Set<String> existentes = new HashSet<>(depreciacionRepository.findPeriodosByActivo(activo));
        List<DepreciacionActivo> nuevos = new ArrayList<>();
        LocalDateTime ahora = LocalDateTime.now();
        for (DepreciacionCalculadora.Fila fila : filas) {
            if (existentes.contains(fila.periodo())) {
                continue;
            }
            nuevos.add(DepreciacionActivo.builder()
                    .activo(activo)
                    .periodo(fila.periodo())
                    .depreciacionPeriodo(fila.depreciacionPeriodo())
                    .depreciacionAcumulada(fila.depreciacionAcumulada())
                    .valorEnLibros(fila.valorEnLibros())
                    .fechaCalculo(ahora)
                    .build());
        }
        depreciacionRepository.saveAll(nuevos);
        return nuevos.size();
    }

    @Transactional
    public CalculoDepreciacionResponse calcularTodos(YearMonth hasta) {
        Long empresaId = TenantContext.getEmpresaId();
        if (empresaId == null || TenantResolver.ROOT.equals(empresaId)) {
            // Contexto de plataforma (programador mensual o calculo al
            // arrancar): se recorre empresa por empresa y cada calculo corre
            // con el tenant de esa empresa. Asi la depreciacion queda
            // asociada a su empresa y no al centinela de la plataforma.
            int procesados = 0;
            int generados = 0;
            for (Empresa empresa : empresaRepository.findAll()) {
                if (empresa.getId() == null || empresa.getId() <= 0) {
                    continue;
                }
                int[] resultado = new int[2];
                calcularDeEmpresa(empresa.getId(), hasta, resultado);
                procesados += resultado[0];
                generados += resultado[1];
            }
            return new CalculoDepreciacionResponse(hasta.toString(), procesados, generados);
        }
        int procesados = 0;
        int generados = 0;
        for (Activo activo : activoRepository.findAll()) {
            if (!parametros(activo).depreciable()) {
                continue;
            }
            procesados++;
            generados += calcularActivo(activo, hasta);
        }
        return new CalculoDepreciacionResponse(hasta.toString(), procesados, generados);
    }

    /**
     * Calcula la depreciacion de una empresa concreta en su propia
     * transaccion (con su tenant), para que las filas se guarden con el
     * empresa_id correcto.
     */
    /**
     * Indica si falta el periodo de depreciacion del mes indicado para algun
     * activo depreciable. Se usa como red de seguridad: los datos de fabrica se
     * siembran despues del arranque y, sin esto, la pantalla de depreciacion
     * se quedaria vacia hasta el proceso mensual.
     */
    @Transactional(readOnly = true)
    public boolean faltaPeriodoActual(YearMonth periodo) {
        String periodoTexto = periodo.toString();
        for (Empresa empresa : empresaRepository.findAll()) {
            if (empresa.getId() == null || empresa.getId() <= TenantResolver.ROOT) {
                continue;
            }
            Long original = TenantContext.getEmpresaId();
            try {
                TenantContext.setEmpresaId(empresa.getId());
                for (Activo activo : activoRepository.findAll()) {
                    if (!parametros(activo).depreciable()) {
                        continue;
                    }
                    if (!depreciacionRepository.findPeriodosByActivo(activo).contains(periodoTexto)) {
                        return true;
                    }
                }
            } finally {
                TenantContext.setEmpresaId(original);
            }
        }
        return false;
    }

    private void calcularDeEmpresa(Long empresaId, YearMonth hasta, int[] resultado) {        Long original = TenantContext.getEmpresaId();
        try {
            // El tenant se fija ANTES de abrir la transaccion: Hibernate
            // resuelve la empresa de la sesion al crearla.
            TenantContext.setEmpresaId(empresaId);
            transaccionNueva.executeWithoutResult(estado -> {
                int procesados = 0;
                int generados = 0;
                for (Activo activo : activoRepository.findAll()) {
                    if (!parametros(activo).depreciable()) {
                        continue;
                    }
                    procesados++;
                    generados += calcularActivo(activo, hasta);
                }
                resultado[0] = procesados;
                resultado[1] = generados;
            });
        } finally {
            TenantContext.setEmpresaId(original);
        }
    }

    @Transactional
    @Auditable(accion = "CALCULAR", entidad = "DEPRECIACION_ACTIVO", idExpresion = "#a0")
    public CalculoDepreciacionResponse calcularDeActivo(Long activoId, YearMonth hasta) {
        Activo activo = activoRepository.findById(activoId)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
        boolean depreciable = parametros(activo).depreciable();
        int generados = calcularActivo(activo, hasta);
        return new CalculoDepreciacionResponse(hasta.toString(), depreciable ? 1 : 0, generados);
    }

    /** Se usa cuando cambian los parametros de una categoria: las filas son datos derivados. */
    @Transactional
    public void recalcularCategoria(Categoria categoria) {
        for (Activo activo : activoRepository.findByCategoria(categoria)) {
            depreciacionRepository.deleteAll(depreciacionRepository.findByActivoOrderByPeriodoAsc(activo));
            depreciacionRepository.flush();
            calcularActivo(activo, YearMonth.now());
        }
    }

    @Transactional(readOnly = true)
    public DepreciacionActivoResponse tabla(Long activoId) {
        Activo activo = activoRepository.findById(activoId)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
        List<DepreciacionActivo> filas = depreciacionRepository.findByActivoOrderByPeriodoAsc(activo);
        DepreciacionActivo ultima = filas.isEmpty() ? null : filas.get(filas.size() - 1);
        List<DepreciacionActivoResponse.Fila> respuesta = filas.stream()
                .map(f -> new DepreciacionActivoResponse.Fila(f.getPeriodo(), f.getDepreciacionPeriodo(),
                        f.getDepreciacionAcumulada(), f.getValorEnLibros()))
                .toList();
        return new DepreciacionActivoResponse(resumen(activo, filas.size(), ultima), respuesta);
    }

    @Transactional(readOnly = true)
    public List<DepreciacionActivoResponse.Resumen> resumenGeneral() {
        Map<Long, DepreciacionActivo> ultimas = new HashMap<>();
        Map<Long, Integer> conteo = new HashMap<>();
        for (DepreciacionActivo d : depreciacionRepository.findAll()) {
            Long id = d.getActivo().getId();
            conteo.merge(id, 1, Integer::sum);
            DepreciacionActivo actual = ultimas.get(id);
            if (actual == null || d.getPeriodo().compareTo(actual.getPeriodo()) > 0) {
                ultimas.put(id, d);
            }
        }
        List<DepreciacionActivoResponse.Resumen> resultado = new ArrayList<>();
        for (Activo activo : activoRepository.findAll()) {
            resultado.add(resumen(activo, conteo.getOrDefault(activo.getId(), 0), ultimas.get(activo.getId())));
        }
        resultado.sort((a, b) -> a.codigo().compareTo(b.codigo()));
        return resultado;
    }

    private DepreciacionActivoResponse.Resumen resumen(Activo activo, int periodos, DepreciacionActivo ultima) {
        Parametros p = parametros(activo);
        BigDecimal cuota = p.depreciable()
                ? p.estrategia().cuotaMensual(p.valor(), p.residual(), p.meses())
                : BigDecimal.ZERO.setScale(2);
        BigDecimal acumulada = ultima == null ? BigDecimal.ZERO.setScale(2) : ultima.getDepreciacionAcumulada();
        BigDecimal enLibros = ultima == null ? p.valor() : ultima.getValorEnLibros();
        Categoria categoria = activo.getCategoria();
        String observacion = p.depreciable() ? null : "La categoría " + categoria.getNombre() + " no es depreciable";
        EstadoActivo estado = activo.getEstado() == null ? EstadoActivo.DISPONIBLE : activo.getEstado();
        return new DepreciacionActivoResponse.Resumen(
                activo.getId(), activo.getCodigo(), activo.getNombre(), categoria.getNombre(), estado.name(),
                p.depreciable(), observacion, p.valor(), p.residual(),
                p.depreciable() ? categoria.getVidaUtil() : null,
                p.depreciable() ? p.meses() : null,
                cuota, acumulada, enLibros, periodos, ultima == null ? null : ultima.getPeriodo());
    }
}
