package com.uagrm.activos.controller;

import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.model.Empresa;
import com.uagrm.activos.model.EstadoEmpresa;
import com.uagrm.activos.pagos.PagosService;
import com.uagrm.activos.saas.EmpresaAdminService;
import com.uagrm.activos.service.DatosEjemploService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/** HU-12: administracion de la plataforma, reservada al Super Admin. */
@RestController
@RequestMapping("/api/plataforma")
@PreAuthorize("hasRole('SUPER_ADMIN')")
public class PlataformaController {

    private final EmpresaAdminService empresaAdminService;
    private final DatosEjemploService datosEjemploService;
    private final PagosService pagosService;

    public PlataformaController(EmpresaAdminService empresaAdminService,
                                DatosEjemploService datosEjemploService,
                                PagosService pagosService) {
        this.empresaAdminService = empresaAdminService;
        this.datosEjemploService = datosEjemploService;
        this.pagosService = pagosService;
    }

    @GetMapping("/empresas")
    public List<Empresa> empresas() {
        return empresaAdminService.listarEmpresas();
    }

    @GetMapping("/metricas")
    public Map<String, Object> metricas() {
        return empresaAdminService.metricasPlataforma();
    }

    @GetMapping("/empresas/{id}")
    public Map<String, Object> detalle(@PathVariable Long id) {
        return empresaAdminService.detalleEmpresa(id);
    }

    @PostMapping("/empresas/{id}/estado")
    public Empresa cambiarEstado(@PathVariable Long id, @RequestParam EstadoEmpresa estado) {
        return empresaAdminService.cambiarEstado(id, estado);
    }

    /**
     * El Super Admin entra a una empresa concreta: devuelve una sesion nueva
     * con el contexto de esa empresa para poder usar todos los modulos
     * (web y movil) viendo los datos de esa empresa.
     */
    @PostMapping("/empresas/{id}/entrar")
    public LoginResponse entrarComoEmpresa(@PathVariable Long id) {
        return empresaAdminService.entrarComoEmpresa(id);
    }

    /**
     * Ronda 10: completa los datos de ejemplo de una empresa (categorias,
     * areas, ubicaciones, activos, asignaciones, mantenimiento, presupuesto,
     * consultas, inventario, historial, configuracion y respaldos). Solo
     * crea lo que le falta: nunca pisa datos reales.
     */
    @PostMapping("/empresas/{id}/datos-ejemplo")
    public Map<String, Object> completarDatosEjemplo(@PathVariable Long id) {
        return datosEjemploService.completar(id);
    }

    /** Completa los datos de ejemplo de todas las empresas de la plataforma. */
    @PostMapping("/datos-ejemplo")
    public Map<String, Object> completarDatosEjemploTodas() {
        return datosEjemploService.completarTodas();
    }

    // ------------------------------------------------- pagos y transferencias

    /**
     * Transferencias bancarias registradas, para que el administrador de la
     * plataforma concilie los depositos y active las suscripciones.
     */
    @GetMapping("/pagos/transferencias")
    public List<Map<String, Object>> transferencias() {
        return pagosService.transferenciasPendientes();
    }

    /** Confirma el deposito: la suscripcion queda activa. */
    @PostMapping("/pagos/transferencias/{referencia}/aprobar")
    public Map<String, Object> aprobarTransferencia(@PathVariable String referencia) {
        return pagosService.aprobarTransferencia(referencia);
    }

    /** Rechaza la transferencia (deposito no recibido o monto incorrecto). */
    @PostMapping("/pagos/transferencias/{referencia}/rechazar")
    public Map<String, Object> rechazarTransferencia(@PathVariable String referencia,
                                                     @RequestParam(required = false) String motivo) {
        return pagosService.rechazarTransferencia(referencia, motivo);
    }
}
