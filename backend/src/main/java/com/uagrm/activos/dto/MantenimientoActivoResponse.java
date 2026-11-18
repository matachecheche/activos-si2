package com.uagrm.activos.dto;

import java.math.BigDecimal;
import java.util.List;

/** HU-08: historial de mantenimientos del activo y costo total acumulado. */
public record MantenimientoActivoResponse(List<MantenimientoResponse> items, BigDecimal costoTotal) {}
