package com.uagrm.activos.inventario;

import com.uagrm.activos.auditoria.AuditoriaService;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.VerificacionInventario;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.VerificacionInventarioRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** HU-17: verificacion fisica de activos con GPS y evidencia fotografica. */
@Service
public class VerificacionInventarioService {

    public static final Set<String> RESULTADOS = Set.of("ENCONTRADO", "NO_ENCONTRADO", "DIFERENCIA_ESTADO");

    private final VerificacionInventarioRepository repo;
    private final ActivoRepository activoRepository;
    private final ArchivoService archivoService;
    private final AuditoriaService auditoriaService;

    public VerificacionInventarioService(VerificacionInventarioRepository repo,
                                         ActivoRepository activoRepository,
                                         ArchivoService archivoService,
                                         AuditoriaService auditoriaService) {
        this.repo = repo;
        this.activoRepository = activoRepository;
        this.archivoService = archivoService;
        this.auditoriaService = auditoriaService;
    }

    @Transactional
    public VerificacionInventario registrar(Long activoId, String resultado, Double latitud, Double longitud,
                                            Double precisionM, String observacion, String fotoUrl) {
        if (!RESULTADOS.contains(resultado)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Resultado invalido: " + resultado);
        }
        Activo activo = activoRepository.findById(activoId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Activo no encontrado"));
        validarGps(latitud, longitud);

        VerificacionInventario v = VerificacionInventario.builder()
                .activoId(activo.getId())
                .usuarioId(TenantContext.getUsuarioId())
                .latitud(latitud)
                .longitud(longitud)
                .precisionM(precisionM)
                .resultado(resultado)
                .observacion(observacion)
                .fotoUrl(fotoUrl)
                .build();
        VerificacionInventario guardado = repo.save(v);
        auditoriaService.registrar("VERIFICAR_INVENTARIO", "VERIFICACION_INVENTARIO",
                String.valueOf(guardado.getId()),
                "Activo " + activo.getCodigo() + " resultado " + resultado);
        return guardado;
    }

    /** HU-17: asocia la foto de un activo (tambien usada por el alta desde el movil). */
    @Transactional
    public Activo asignarFotoActivo(Long activoId, String fotoUrl) {
        Activo activo = activoRepository.findById(activoId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Activo no encontrado"));
        activo.setFotoUrl(fotoUrl);
        return activoRepository.save(activo);
    }

    @Transactional(readOnly = true)
    public Page<VerificacionInventario> listar(int pagina, int tamano) {
        return repo.findByEmpresaIdOrderByFechaHoraDesc(TenantContext.getEmpresaId(),
                PageRequest.of(pagina, Math.min(tamano, 100)));
    }

    @Transactional(readOnly = true)
    public Map<String, Object> estadisticas() {
        Long empresaId = TenantContext.getEmpresaId();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("encontrados", repo.countByEmpresaIdAndResultado(empresaId, "ENCONTRADO"));
        m.put("noEncontrados", repo.countByEmpresaIdAndResultado(empresaId, "NO_ENCONTRADO"));
        m.put("diferenciaEstado", repo.countByEmpresaIdAndResultado(empresaId, "DIFERENCIA_ESTADO"));
        m.put("ultimas", repo.findByEmpresaIdOrderByFechaHoraDesc(empresaId, PageRequest.of(0, 10)).getContent());
        return m;
    }

    /** El GPS es opcional (permiso denegado o sin senal), pero si llega debe ser coherente. */
    private void validarGps(Double lat, Double lon) {
        if (lat == null && lon == null) {
            return;
        }
        if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Coordenadas GPS invalidas");
        }
    }

    public ArchivoService archivos() {
        return archivoService;
    }
}
