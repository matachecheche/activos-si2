package com.uagrm.activos.dto;

public record UsuarioResponse(Long id, String nombre, String correo, String rol, Boolean activo) {}