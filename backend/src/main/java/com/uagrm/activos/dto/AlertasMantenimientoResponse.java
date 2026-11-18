package com.uagrm.activos.dto;

import java.util.List;

/** HU-08: mantenimientos que vencen en los proximos 7 dias y vencidos sin ejecutar. */
public record AlertasMantenimientoResponse(List<MantenimientoResponse> proximos, List<MantenimientoResponse> vencidos) {}
