package com.uagrm.activos.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Respuesta plana del activo. Conserva el objeto anidado "categoria" por compatibilidad
 * con la app movil de Sprint 1 y no expone datos sensibles del responsable.
 */
public record ActivoResponse(
        Long id,
        String codigo,
        String nombre,
        CategoriaRef categoria,
        Long categoriaId,
        String categoriaNombre,
        BigDecimal valor,
        BigDecimal valorResidual,
        LocalDate fechaAdquisicion,
        LocalDate fechaInicioDepreciacion,
        LocalDate fechaBaja,
        String proveedor,
        String observaciones,
        String estado,
        String estadoEtiqueta,
        UsuarioRef responsable,
        UbicacionRef ubicacion,
        List<String> estadosPermitidos,
        Boolean editable
) {
    public record CategoriaRef(Long id, String nombre) {}

    public record UsuarioRef(Long id, String nombre, String correo) {}

    public record UbicacionRef(Long id, String nombre) {}
}
