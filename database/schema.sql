-- Sistema de Activos Fijos y Presupuestos - Grupo 7
-- Modelo conceptual inicial del Sprint 1 (Usuario, Rol, Activo, Categoria, Ubicacion, Asignacion)
-- Nota: la base de datos "activos_fijos_db" ya se crea desde setup.ps1 antes de correr este script.

CREATE TABLE IF NOT EXISTS rol (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS usuario (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    rol_id BIGINT NOT NULL REFERENCES rol(id),
    intentos_fallidos INT NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMP NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS permiso (
    id BIGSERIAL PRIMARY KEY,
    modulo VARCHAR(50) NOT NULL,
    accion VARCHAR(20) NOT NULL,
    descripcion VARCHAR(160) NOT NULL DEFAULT '',
    UNIQUE (modulo, accion)
);

ALTER TABLE permiso ADD COLUMN IF NOT EXISTS descripcion VARCHAR(160) NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS rol_permiso (
    rol_id BIGINT NOT NULL REFERENCES rol(id) ON DELETE CASCADE,
    permiso_id BIGINT NOT NULL REFERENCES permiso(id) ON DELETE CASCADE,
    PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE IF NOT EXISTS categoria (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS ubicacion (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL
);

CREATE TABLE IF NOT EXISTS activo (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    categoria_id BIGINT NOT NULL REFERENCES categoria(id),
    valor NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    fecha_adquisicion DATE NOT NULL,
    proveedor VARCHAR(150),
    observaciones TEXT,
    estado VARCHAR(20) NOT NULL DEFAULT 'SIN_ASIGNAR',
    responsable_id BIGINT REFERENCES usuario(id),
    ubicacion_id BIGINT REFERENCES ubicacion(id)
);

CREATE TABLE IF NOT EXISTS asignacion (
    id BIGSERIAL PRIMARY KEY,
    activo_id BIGINT NOT NULL REFERENCES activo(id),
    responsable_id BIGINT NOT NULL REFERENCES usuario(id),
    ubicacion_id BIGINT NOT NULL REFERENCES ubicacion(id),
    fecha_asignacion TIMESTAMP NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE
);

-- Datos semilla
-- Se insertan con "WHERE NOT EXISTS" y no con ON CONFLICT porque este archivo
-- tiene que funcionar en los DOS casos:
--   1) base nueva: la tabla se crea aqui con UNIQUE(nombre)
--   2) base ya migrada por el backend (Sprint 3): la unicidad pasa a ser
--      UNIQUE(empresa_id, nombre) y "ON CONFLICT (nombre)" ya no valida.
-- Asi el despliegue en Azure nunca se detiene por esto.
INSERT INTO rol (nombre)
    SELECT 'ADMINISTRADOR' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = 'ADMINISTRADOR')
    UNION ALL SELECT 'ENCARGADO_ACTIVOS' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = 'ENCARGADO_ACTIVOS')
    UNION ALL SELECT 'CONTADOR' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = 'CONTADOR')
    UNION ALL SELECT 'RESPONSABLE_FINANCIERO' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = 'RESPONSABLE_FINANCIERO');

INSERT INTO categoria (nombre)
    SELECT 'Mobiliario' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = 'Mobiliario')
    UNION ALL SELECT 'Equipos informaticos' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = 'Equipos informaticos')
    UNION ALL SELECT 'Vehiculos' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = 'Vehiculos')
    UNION ALL SELECT 'Maquinaria' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = 'Maquinaria')
    UNION ALL SELECT 'Inmuebles' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = 'Inmuebles');

INSERT INTO permiso (modulo, accion, descripcion)
    SELECT 'ACTIVOS', 'LEER', 'Consultar activos registrados' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'LEER')
    UNION ALL SELECT 'ACTIVOS', 'CREAR', 'Registrar activos nuevos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'CREAR')
    UNION ALL SELECT 'ACTIVOS', 'EDITAR', 'Modificar datos de activos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'EDITAR')
    UNION ALL SELECT 'ACTIVOS', 'ELIMINAR', 'Dar de baja activos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'ELIMINAR')
    UNION ALL SELECT 'PRESUPUESTO', 'LEER', 'Consultar presupuestos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'LEER')
    UNION ALL SELECT 'PRESUPUESTO', 'CREAR', 'Registrar presupuesto anual' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'CREAR')
    UNION ALL SELECT 'PRESUPUESTO', 'EDITAR', 'Modificar presupuesto' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'EDITAR')
    UNION ALL SELECT 'PRESUPUESTO', 'ELIMINAR', 'Eliminar presupuesto' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'ELIMINAR')
    UNION ALL SELECT 'REPORTES', 'LEER', 'Consultar reportes y estadisticas' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'REPORTES' AND accion = 'LEER')
    UNION ALL SELECT 'USUARIOS', 'LEER', 'Consultar usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'LEER')
    UNION ALL SELECT 'USUARIOS', 'CREAR', 'Crear usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'CREAR')
    UNION ALL SELECT 'USUARIOS', 'EDITAR', 'Modificar usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'EDITAR')
    UNION ALL SELECT 'USUARIOS', 'ELIMINAR', 'Desactivar usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'ELIMINAR');

UPDATE permiso SET descripcion = 'Consultar activos registrados' WHERE modulo = 'ACTIVOS' AND accion = 'LEER' AND descripcion = '';
UPDATE permiso SET descripcion = 'Registrar activos nuevos' WHERE modulo = 'ACTIVOS' AND accion = 'CREAR' AND descripcion = '';
UPDATE permiso SET descripcion = 'Modificar datos de activos' WHERE modulo = 'ACTIVOS' AND accion = 'EDITAR' AND descripcion = '';
UPDATE permiso SET descripcion = 'Dar de baja activos' WHERE modulo = 'ACTIVOS' AND accion = 'ELIMINAR' AND descripcion = '';
UPDATE permiso SET descripcion = 'Consultar usuarios' WHERE modulo = 'USUARIOS' AND accion = 'LEER' AND descripcion = '';
UPDATE permiso SET descripcion = 'Crear usuarios' WHERE modulo = 'USUARIOS' AND accion = 'CREAR' AND descripcion = '';
UPDATE permiso SET descripcion = 'Modificar usuarios' WHERE modulo = 'USUARIOS' AND accion = 'EDITAR' AND descripcion = '';
UPDATE permiso SET descripcion = 'Desactivar usuarios' WHERE modulo = 'USUARIOS' AND accion = 'ELIMINAR' AND descripcion = '';

INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id FROM rol r CROSS JOIN permiso p
WHERE r.nombre = 'ENCARGADO_ACTIVOS'
    AND p.modulo = 'ACTIVOS'
    AND p.accion IN ('LEER', 'CREAR', 'EDITAR')
ON CONFLICT DO NOTHING;

INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id FROM rol r CROSS JOIN permiso p
WHERE r.nombre = 'CONTADOR'
    AND p.modulo IN ('ACTIVOS', 'REPORTES')
    AND p.accion = 'LEER'
ON CONFLICT DO NOTHING;

INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id FROM rol r CROSS JOIN permiso p
WHERE r.nombre = 'RESPONSABLE_FINANCIERO'
    AND p.modulo = 'PRESUPUESTO'
    AND p.accion IN ('LEER', 'CREAR', 'EDITAR')
ON CONFLICT DO NOTHING;

-- Usuario de prueba (password: "admin123" ya cifrado con BCrypt)
-- Generar el hash real con BCrypt antes de usar en produccion.
-- INSERT INTO usuario (nombre, correo, password, rol_id)
-- VALUES ('Administrador', 'admin@uagrm.edu.bo', '<hash_bcrypt>', 1);
