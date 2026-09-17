package com.uagrm.activos.config;

import com.uagrm.activos.model.Permiso;
import com.uagrm.activos.model.Rol;
import com.uagrm.activos.repository.PermisoRepository;
import com.uagrm.activos.repository.RolRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;
import java.util.Map;

@Configuration
public class PermissionDataInitializer {
    private static final Map<String, List<String>> DEFAULT_PERMISSIONS = Map.of(
            "ACTIVOS", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"),
            "PRESUPUESTO", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"),
            "REPORTES", List.of("LEER"),
            "USUARIOS", List.of("LEER", "CREAR", "EDITAR", "ELIMINAR"));

    @Bean
    CommandLineRunner initializePermissions(PermisoRepository permisoRepository, RolRepository rolRepository) {
        return args -> {
            for (Map.Entry<String, List<String>> entry : DEFAULT_PERMISSIONS.entrySet()) {
                for (String accion : entry.getValue()) {
                    if (permisoRepository.findAll().stream().noneMatch(p -> p.getModulo().equals(entry.getKey()) && p.getAccion().equals(accion))) {
                        permisoRepository.save(Permiso.builder()
                                .modulo(entry.getKey()).accion(accion)
                                .descripcion(descripcion(entry.getKey(), accion)).build());
                    }
                }
            }
            List<Permiso> permisos = permisoRepository.findAll();
            rolRepository.findByNombre("ADMINISTRADOR").ifPresent(rol -> asignarTodos(rol, permisos, rolRepository));
            rolRepository.findByNombre("ENCARGADO_ACTIVOS").ifPresent(rol -> asignar(rol, permisos, "ACTIVOS", List.of("LEER", "CREAR", "EDITAR"), rolRepository));
            rolRepository.findByNombre("CONTADOR").ifPresent(rol -> asignar(rol, permisos, "ACTIVOS", List.of("LEER"), rolRepository));
            rolRepository.findByNombre("CONTADOR").ifPresent(rol -> asignar(rol, permisos, "REPORTES", List.of("LEER"), rolRepository));
            rolRepository.findByNombre("RESPONSABLE_FINANCIERO").ifPresent(rol -> asignar(rol, permisos, "PRESUPUESTO", List.of("LEER", "CREAR", "EDITAR"), rolRepository));
        };
    }

    private void asignarTodos(Rol rol, List<Permiso> permisos, RolRepository repository) { rol.getPermisos().addAll(permisos); repository.save(rol); }

    private void asignar(Rol rol, List<Permiso> permisos, String modulo, List<String> acciones, RolRepository repository) {
        permisos.stream().filter(p -> p.getModulo().equals(modulo) && acciones.contains(p.getAccion())).forEach(rol.getPermisos()::add);
        repository.save(rol);
    }

    private String descripcion(String modulo, String accion) { return switch (modulo + "_" + accion) {
        case "ACTIVOS_LEER" -> "Consultar activos registrados";
        case "ACTIVOS_CREAR" -> "Registrar activos nuevos";
        case "ACTIVOS_EDITAR" -> "Modificar datos de activos";
        case "ACTIVOS_ELIMINAR" -> "Dar de baja activos";
        case "USUARIOS_LEER" -> "Consultar usuarios";
        case "USUARIOS_CREAR" -> "Crear usuarios";
        case "USUARIOS_EDITAR" -> "Modificar usuarios";
        case "USUARIOS_ELIMINAR" -> "Desactivar usuarios";
        default -> accion + " en " + modulo.toLowerCase();
    }; }
}
