package com.uagrm.activos.controller;

import com.uagrm.activos.dto.RegistroEmpresaRequest;
import com.uagrm.activos.dto.RegistroEmpresaResponse;
import com.uagrm.activos.model.Plan;
import com.uagrm.activos.pagos.PagosService;
import com.uagrm.activos.saas.RegistroEmpresaService;
import com.uagrm.activos.saas.SuscripcionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/** HU-11: endpoints publicos (sin autenticar): catalogo de planes y alta de empresa. */
@RestController
@RequestMapping("/api/public")
public class PublicController {

    private final SuscripcionService suscripcionService;
    private final RegistroEmpresaService registroEmpresaService;
    private final PagosService pagosService;

    public PublicController(SuscripcionService suscripcionService,
                            RegistroEmpresaService registroEmpresaService,
                            PagosService pagosService) {
        this.suscripcionService = suscripcionService;
        this.registroEmpresaService = registroEmpresaService;
        this.pagosService = pagosService;
    }

    @GetMapping("/planes")
    public List<Plan> planes() {
        return suscripcionService.listarPlanes();
    }

    /**
     * Metodos de pago disponibles para el alta de empresa (Stripe, QR,
     * transferencia bancaria...). Se puede consultar sin iniciar sesion.
     */
    @GetMapping("/metodos-pago")
    public List<Map<String, Object>> metodosPago() {
        return pagosService.metodosDisponibles();
    }

    /**
     * Estado de un pago abierto con el codigo de referencia (por ejemplo una
     * transferencia bancaria). No expone datos de la empresa: solo el estado
     * del cobro, para que quien registro la empresa pueda consultarlo sin
     * iniciar sesion.
     */
    @GetMapping("/pagos/{referencia}")
    public Map<String, Object> estadoPago(@PathVariable String referencia) {
        return pagosService.estadoPublicoPago(referencia);
    }

    @PostMapping("/registro-empresa")
    public RegistroEmpresaResponse registrar(@Valid @RequestBody RegistroEmpresaRequest request) {
        RegistroEmpresaResponse respuesta = registroEmpresaService.registrar(request);
        // Ronda 10: la empresa nueva nace con datos de ejemplo en todas las
        // pantallas (activos, presupuestos, mantenimiento, inventario, etc.).
        // Se hace despues del alta, cuando la transaccion ya confirmo.
        registroEmpresaService.sembrarDatosEjemplo(respuesta.getEmpresaId());
        // Ronda 11: con el metodo de pago elegido se abre el cobro real
        // (Stripe, QR o transferencia bancaria) para que la empresa pueda
        // pagar desde el mismo momento.
        return registroEmpresaService.abrirCobro(respuesta, request);
    }
}
