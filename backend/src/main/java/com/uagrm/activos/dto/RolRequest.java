package com.uagrm.activos.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.Set;

public record RolRequest(@NotBlank String nombre, Set<Long> permisos) {}