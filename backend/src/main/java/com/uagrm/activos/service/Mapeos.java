package com.uagrm.activos.service;

import com.uagrm.activos.domain.ReglasEstadoActivo;
import com.uagrm.activos.dto.ActivoResponse;
import com.uagrm.activos.dto.AreaResponse;
import com.uagrm.activos.dto.CategoriaResponse;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Area;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.model.Ubicacion;
import com.uagrm.activos.model.Usuario;

import java.util.List;

/** Conversiones entidad -> DTO (los controladores no exponen entidades ni contrasenas). */
public final class Mapeos {

    private Mapeos() {
    }

    public static ActivoResponse.UsuarioRef usuarioRef(Usuario usuario) {
        return usuario == null ? null : new ActivoResponse.UsuarioRef(usuario.getId(), usuario.getNombre(), usuario.getCorreo());
    }

    public static ActivoResponse.UbicacionRef ubicacionRef(Ubicacion ubicacion) {
        return ubicacion == null ? null : new ActivoResponse.UbicacionRef(ubicacion.getId(), ubicacion.getNombre());
    }

    public static ActivoResponse activo(Activo a, Boolean editable) {
        EstadoActivo estado = a.getEstado() == null ? EstadoActivo.DISPONIBLE : a.getEstado();
        Categoria c = a.getCategoria();
        List<String> permitidos = ReglasEstadoActivo.destinosManuales(estado).stream().map(EstadoActivo::name).toList();
        return new ActivoResponse(
                a.getId(),
                a.getCodigo(),
                a.getNombre(),
                c == null ? null : new ActivoResponse.CategoriaRef(c.getId(), c.getNombre()),
                c == null ? null : c.getId(),
                c == null ? null : c.getNombre(),
                a.getValor(),
                a.getValorResidual(),
                a.getFechaAdquisicion(),
                a.getFechaInicioDepreciacion(),
                a.getFechaBaja(),
                a.getProveedor(),
                a.getObservaciones(),
                estado.name(),
                estado.getEtiqueta(),
                usuarioRef(a.getResponsable()),
                ubicacionRef(a.getUbicacion()),
                permitidos,
                editable);
    }

    public static CategoriaResponse categoria(Categoria c) {
        return new CategoriaResponse(c.getId(), c.getNombre(), c.getVidaUtil(), c.getMetodoDepreciacion(),
                c.getValorResidualPct(), Boolean.TRUE.equals(c.getDepreciable()));
    }

    public static AreaResponse area(Area a) {
        return new AreaResponse(a.getId(), a.getNombre(), a.getDescripcion(), !Boolean.FALSE.equals(a.getActivo()));
    }
}
