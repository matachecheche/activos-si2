package com.uagrm.activos.model;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Guarda el estado como texto sin generar una restriccion CHECK en la base de datos
 * (las bases creadas en Sprint 1 traen una CHECK con los estados antiguos) y acepta
 * los valores historicos de Sprint 1.
 */
@Converter
public class EstadoActivoConverter implements AttributeConverter<EstadoActivo, String> {

    @Override
    public String convertToDatabaseColumn(EstadoActivo estado) {
        return estado == null ? null : estado.name();
    }

    @Override
    public EstadoActivo convertToEntityAttribute(String valor) {
        return valor == null ? null : EstadoActivo.desdeTexto(valor);
    }
}
