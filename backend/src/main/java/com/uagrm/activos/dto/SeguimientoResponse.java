package com.uagrm.activos.dto;

import java.util.List;

/** HU-10: planificado vs. ejecutado por partida y por presupuesto. */
public record SeguimientoResponse(PresupuestoResponse presupuesto, List<PartidaResponse> partidas) {}
