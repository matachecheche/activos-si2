package com.uagrm.activos.dto;

import java.util.Set;

public record RolResponse(
        Long id,
        String nombre,
        String descripcion,
        Boolean activo,
        Set<PermisoResponse> permisos,
        long usuariosActivos
) {}
