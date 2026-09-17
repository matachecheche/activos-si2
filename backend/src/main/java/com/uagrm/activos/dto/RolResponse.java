package com.uagrm.activos.dto;

import java.util.Set;

public record RolResponse(Long id, String nombre, Set<PermisoResponse> permisos) {}