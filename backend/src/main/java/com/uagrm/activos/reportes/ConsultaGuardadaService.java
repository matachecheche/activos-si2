package com.uagrm.activos.reportes;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.uagrm.activos.auditoria.Auditable;
import com.uagrm.activos.ia.ConsultaEspec;
import com.uagrm.activos.ia.MotorConsultaSql;
import com.uagrm.activos.ia.ResultadoConsulta;
import com.uagrm.activos.model.ConsultaGuardada;
import com.uagrm.activos.repository.ConsultaGuardadaRepository;
import com.uagrm.activos.tenant.TenantContext;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/** HU-14: consultas dinamicas que el usuario guarda para reutilizar. */
@Service
public class ConsultaGuardadaService {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final ConsultaGuardadaRepository repo;
    private final MotorConsultaSql motor;

    public ConsultaGuardadaService(ConsultaGuardadaRepository repo, MotorConsultaSql motor) {
        this.repo = repo;
        this.motor = motor;
    }

    @Transactional(readOnly = true)
    public List<ConsultaGuardada> listar() {
        return repo.findByEmpresaIdOrderByFechaDesc(TenantContext.getEmpresaId());
    }

    @Transactional
    @Auditable(accion = "GUARDAR_CONSULTA", entidad = "CONSULTA_GUARDADA",
            idExpresion = "#resultado.id", detalleExpresion = "#a0.nombre")
    public ConsultaGuardada guardar(String nombre, String entidad, String definicionJson) {
        validarDefinicion(definicionJson);
        ConsultaGuardada c = ConsultaGuardada.builder()
                .nombre(nombre)
                .entidad(entidad)
                .definicion(definicionJson)
                .usuarioId(TenantContext.getUsuarioId())
                .build();
        return repo.save(c);
    }

    @Transactional(readOnly = true)
    public ResultadoConsulta ejecutar(Long id) {
        ConsultaGuardada guardada = repo.findById(id)
                .filter(c -> c.getEmpresaId().equals(TenantContext.getEmpresaId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Consulta guardada no encontrada"));
        try {
            ConsultaEspec espec = MAPPER.readValue(guardada.getDefinicion(), ConsultaEspec.class);
            return motor.ejecutar(espec);
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La definicion guardada ya no es valida");
        }
    }

    @Transactional
    @Auditable(accion = "ELIMINAR_CONSULTA", entidad = "CONSULTA_GUARDADA", idExpresion = "#a0")
    public void eliminar(Long id) {
        ConsultaGuardada guardada = repo.findById(id)
                .filter(c -> c.getEmpresaId().equals(TenantContext.getEmpresaId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Consulta guardada no encontrada"));
        repo.delete(guardada);
    }

    private void validarDefinicion(String definicionJson) {
        try {
            ConsultaEspec espec = MAPPER.readValue(definicionJson, ConsultaEspec.class);
            int limiteOriginal = espec.limite;
            espec.limite = 1; // validacion economica: solo comprueba que la estructura es ejecutable
            motor.ejecutar(espec);
            espec.limite = limiteOriginal;
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La definicion de la consulta no es valida: " + e.getMessage());
        }
    }
}
