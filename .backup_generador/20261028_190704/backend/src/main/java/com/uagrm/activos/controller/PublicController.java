package com.uagrm.activos.controller;

import com.uagrm.activos.dto.RegistroEmpresaRequest;
import com.uagrm.activos.dto.RegistroEmpresaResponse;
import com.uagrm.activos.model.Plan;
import com.uagrm.activos.saas.RegistroEmpresaService;
import com.uagrm.activos.saas.SuscripcionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** HU-11: endpoints publicos (sin autenticar): catalogo de planes y alta de empresa. */
@RestController
@RequestMapping("/api/public")
public class PublicController {

    private final SuscripcionService suscripcionService;
    private final RegistroEmpresaService registroEmpresaService;

    public PublicController(SuscripcionService suscripcionService,
                            RegistroEmpresaService registroEmpresaService) {
        this.suscripcionService = suscripcionService;
        this.registroEmpresaService = registroEmpresaService;
    }

    @GetMapping("/planes")
    public List<Plan> planes() {
        return suscripcionService.listarPlanes();
    }

    @PostMapping("/registro-empresa")
    public RegistroEmpresaResponse registrar(@Valid @RequestBody RegistroEmpresaRequest request) {
        RegistroEmpresaResponse respuesta = registroEmpresaService.registrar(request);
        // Ronda 10: la empresa nueva nace con datos de ejemplo en todas las
        // pantallas (activos, presupuestos, mantenimiento, inventario, etc.).
        // Se hace despues del alta, cuando la transaccion ya confirmo.
        registroEmpresaService.sembrarDatosEjemplo(respuesta.getEmpresaId());
        return respuesta;
    }
}
