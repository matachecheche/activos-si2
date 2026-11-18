-- =====================================================================================
-- Sprint 2 - Migracion V2 (idempotente: se puede ejecutar varias veces sin duplicar datos)
-- Seguridad por roles (HU-04), QR/estado (HU-05/06), depreciacion (HU-07),
-- mantenimiento (HU-08) y presupuestos (HU-09/10).
--
-- Es OPCIONAL: al arrancar, el backend (ddl-auto=update + DatabaseInitializer) aplica lo mismo.
-- Sirve para revisar o preparar la base de datos a mano:
--   psql -U postgres -d activos_fijos_db -f database/migrations/V2__sprint2.sql
-- =====================================================================================

-- ---------- Area y ubicacion ----------
CREATE TABLE IF NOT EXISTS area (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL UNIQUE,
    descripcion VARCHAR(200),
    activo BOOLEAN DEFAULT TRUE
);
ALTER TABLE ubicacion ADD COLUMN IF NOT EXISTS area_id BIGINT REFERENCES area(id);

-- ---------- Roles: descripcion y estado (HU-04) ----------
ALTER TABLE rol ADD COLUMN IF NOT EXISTS descripcion VARCHAR(160);
ALTER TABLE rol ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;
UPDATE rol SET activo = TRUE WHERE activo IS NULL;

-- ---------- Categorias: parametros de depreciacion (HU-07) ----------
ALTER TABLE categoria ADD COLUMN IF NOT EXISTS vida_util INT;                 -- en anios
ALTER TABLE categoria ADD COLUMN IF NOT EXISTS metodo_depreciacion VARCHAR(30);
ALTER TABLE categoria ADD COLUMN IF NOT EXISTS valor_residual_pct NUMERIC(5,2);
ALTER TABLE categoria ADD COLUMN IF NOT EXISTS depreciable BOOLEAN;

INSERT INTO categoria (nombre) VALUES ('Terrenos') ON CONFLICT (nombre) DO NOTHING;

UPDATE categoria SET vida_util = 10, depreciable = TRUE, metodo_depreciacion = 'LINEA_RECTA', valor_residual_pct = 0 WHERE nombre = 'Mobiliario' AND depreciable IS NULL;
UPDATE categoria SET vida_util = 4,  depreciable = TRUE, metodo_depreciacion = 'LINEA_RECTA', valor_residual_pct = 0 WHERE nombre = 'Equipos informaticos' AND depreciable IS NULL;
UPDATE categoria SET vida_util = 5,  depreciable = TRUE, metodo_depreciacion = 'LINEA_RECTA', valor_residual_pct = 0 WHERE nombre = 'Vehiculos' AND depreciable IS NULL;
UPDATE categoria SET vida_util = 8,  depreciable = TRUE, metodo_depreciacion = 'LINEA_RECTA', valor_residual_pct = 0 WHERE nombre = 'Maquinaria' AND depreciable IS NULL;
UPDATE categoria SET vida_util = 40, depreciable = TRUE, metodo_depreciacion = 'LINEA_RECTA', valor_residual_pct = 0 WHERE nombre = 'Inmuebles' AND depreciable IS NULL;
UPDATE categoria SET depreciable = FALSE, metodo_depreciacion = 'LINEA_RECTA', valor_residual_pct = 0 WHERE nombre = 'Terrenos' AND depreciable IS NULL;
UPDATE categoria SET depreciable = FALSE, metodo_depreciacion = COALESCE(metodo_depreciacion, 'LINEA_RECTA') WHERE depreciable IS NULL;

-- ---------- Activos: estados (HU-06) y datos de depreciacion (HU-07) ----------
DO $$
DECLARE r record;
BEGIN
    -- la CHECK de estados del Sprint 1 impediria los nuevos valores
    FOR r IN SELECT conname FROM pg_constraint
             WHERE conrelid = to_regclass('activo') AND contype = 'c' AND pg_get_constraintdef(oid) ILIKE '%estado%' LOOP
        EXECUTE format('ALTER TABLE activo DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;

ALTER TABLE activo ALTER COLUMN estado TYPE VARCHAR(30);
ALTER TABLE activo ALTER COLUMN estado SET DEFAULT 'DISPONIBLE';
ALTER TABLE activo ADD COLUMN IF NOT EXISTS valor_residual NUMERIC(14,2);
ALTER TABLE activo ADD COLUMN IF NOT EXISTS fecha_inicio_depreciacion DATE;
ALTER TABLE activo ADD COLUMN IF NOT EXISTS fecha_baja DATE;

UPDATE activo SET estado = 'DISPONIBLE'       WHERE estado = 'SIN_ASIGNAR';
UPDATE activo SET estado = 'EN_MANTENIMIENTO' WHERE estado = 'MANTENIMIENTO';
UPDATE activo SET estado = 'DADO_DE_BAJA'     WHERE estado = 'BAJA';
UPDATE activo SET fecha_baja = CURRENT_DATE   WHERE estado = 'DADO_DE_BAJA' AND fecha_baja IS NULL;
UPDATE activo SET fecha_inicio_depreciacion = fecha_adquisicion WHERE fecha_inicio_depreciacion IS NULL;

-- ---------- Historial de estados (HU-06) ----------
CREATE TABLE IF NOT EXISTS historial_estado_activo (
    id BIGSERIAL PRIMARY KEY,
    activo_id BIGINT NOT NULL REFERENCES activo(id),
    estado_anterior VARCHAR(30),
    estado_nuevo VARCHAR(30) NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    usuario_id BIGINT REFERENCES usuario(id),
    fecha TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_historial_estado_activo ON historial_estado_activo (activo_id, fecha);

-- ---------- Depreciacion (HU-07): una fila por activo y periodo ----------
CREATE TABLE IF NOT EXISTS depreciacion_activo (
    id BIGSERIAL PRIMARY KEY,
    activo_id BIGINT NOT NULL REFERENCES activo(id),
    periodo VARCHAR(7) NOT NULL,                       -- yyyy-MM
    depreciacion_periodo NUMERIC(14,2) NOT NULL,
    depreciacion_acumulada NUMERIC(14,2) NOT NULL,
    valor_en_libros NUMERIC(14,2) NOT NULL,
    fecha_calculo TIMESTAMP NOT NULL,
    CONSTRAINT uk_depreciacion_activo_periodo UNIQUE (activo_id, periodo)
);

-- ---------- Mantenimientos (HU-08) ----------
CREATE TABLE IF NOT EXISTS mantenimiento (
    id BIGSERIAL PRIMARY KEY,
    activo_id BIGINT NOT NULL REFERENCES activo(id),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('PREVENTIVO', 'CORRECTIVO')),
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('PROGRAMADO', 'EN_EJECUCION', 'FINALIZADO', 'CANCELADO')),
    descripcion VARCHAR(500),
    fecha_programada DATE,
    periodicidad_dias INT,
    fecha_inicio TIMESTAMP,
    fecha_realizada DATE,
    costo NUMERIC(14,2),
    tecnico VARCHAR(150),
    observaciones VARCHAR(500),
    estado_previo_activo VARCHAR(30),
    fecha_creacion TIMESTAMP,
    creado_por_id BIGINT REFERENCES usuario(id)
);
CREATE INDEX IF NOT EXISTS idx_mantenimiento_activo ON mantenimiento (activo_id, estado);

-- ---------- Presupuestos (HU-09) y ejecucion (HU-10) ----------
CREATE TABLE IF NOT EXISTS presupuesto (
    id BIGSERIAL PRIMARY KEY,
    area_id BIGINT NOT NULL REFERENCES area(id),
    gestion INT NOT NULL,
    monto_aprobado NUMERIC(14,2) NOT NULL,
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('BORRADOR', 'APROBADO', 'CERRADO')),
    fecha_aprobacion TIMESTAMP,
    usuario_aprobador_id BIGINT REFERENCES usuario(id),
    CONSTRAINT uk_presupuesto_area_gestion UNIQUE (area_id, gestion)
);

CREATE TABLE IF NOT EXISTS partida_presupuestaria (
    id BIGSERIAL PRIMARY KEY,
    presupuesto_id BIGINT NOT NULL REFERENCES presupuesto(id),
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    monto_planificado NUMERIC(14,2) NOT NULL,
    CONSTRAINT uk_partida_presupuesto_codigo UNIQUE (presupuesto_id, codigo)
);

CREATE TABLE IF NOT EXISTS ejecucion_presupuestaria (
    id BIGSERIAL PRIMARY KEY,
    partida_id BIGINT NOT NULL REFERENCES partida_presupuestaria(id),
    fecha DATE NOT NULL,
    concepto VARCHAR(200) NOT NULL,
    monto NUMERIC(14,2) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('COMPROMISO', 'EJECUCION')),
    activo_id BIGINT REFERENCES activo(id),
    compromiso_id BIGINT REFERENCES ejecucion_presupuestaria(id),
    usuario_id BIGINT REFERENCES usuario(id)
);
CREATE INDEX IF NOT EXISTS idx_ejecucion_partida ON ejecucion_presupuestaria (partida_id);

-- ---------- Areas iniciales ----------
INSERT INTO area (nombre, descripcion, activo)
SELECT v.nombre, v.descripcion, TRUE
FROM (VALUES
    ('Dirección administrativa', 'Administración general de la facultad'),
    ('Sistemas', 'Infraestructura y soporte informático'),
    ('Laboratorios', 'Laboratorios de redes y cómputo'),
    ('Biblioteca', 'Biblioteca y centro de documentación'),
    ('Almacén', 'Almacén central de bienes')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM area a WHERE lower(a.nombre) = lower(v.nombre));

-- ---------- Roles y permisos (HU-04) ----------
-- Rol TECNICO (nuevo). Si ya existe no se toca.
WITH nuevo_rol AS (
    INSERT INTO rol (nombre, descripcion, activo)
    SELECT 'TECNICO', 'Programa y registra mantenimientos', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = 'TECNICO')
    RETURNING id
)
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT nr.id, p.id FROM nuevo_rol nr CROSS JOIN permiso p
WHERE (p.modulo = 'ACTIVOS' AND p.accion = 'LEER')
   OR (p.modulo = 'MANTENIMIENTO' AND p.accion IN ('LEER', 'CREAR', 'EDITAR'))
ON CONFLICT DO NOTHING;

UPDATE rol SET descripcion = 'Acceso total al sistema'                       WHERE nombre = 'ADMINISTRADOR' AND descripcion IS NULL;
UPDATE rol SET descripcion = 'Registra, asigna y controla los activos fijos' WHERE nombre = 'ENCARGADO_ACTIVOS' AND descripcion IS NULL;
UPDATE rol SET descripcion = 'Consulta activos y administra la depreciación' WHERE nombre = 'CONTADOR' AND descripcion IS NULL;
UPDATE rol SET descripcion = 'Administra presupuestos y su ejecución'        WHERE nombre = 'RESPONSABLE_FINANCIERO' AND descripcion IS NULL;

-- Permisos nuevos. Solo los permisos que se crean ahora se asignan a los roles por defecto,
-- asi lo que el administrador quite despues desde "Roles y permisos" no se vuelve a agregar.
WITH nuevos AS (
    INSERT INTO permiso (modulo, accion, descripcion) VALUES
        ('DEPRECIACION', 'LEER', 'Consultar depreciación'),
        ('DEPRECIACION', 'CREAR', 'Calcular la depreciación'),
        ('DEPRECIACION', 'EDITAR', 'Parametrizar la depreciación por categoría'),
        ('DEPRECIACION', 'ELIMINAR', 'Eliminar depreciación'),
        ('MANTENIMIENTO', 'LEER', 'Consultar mantenimientos'),
        ('MANTENIMIENTO', 'CREAR', 'Registrar mantenimientos'),
        ('MANTENIMIENTO', 'EDITAR', 'Modificar mantenimientos'),
        ('MANTENIMIENTO', 'ELIMINAR', 'Eliminar mantenimientos')
    ON CONFLICT (modulo, accion) DO NOTHING
    RETURNING id, modulo, accion
)
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, n.id
FROM nuevos n
JOIN rol r ON r.nombre = 'ADMINISTRADOR'
   OR (r.nombre = 'ENCARGADO_ACTIVOS' AND ((n.modulo = 'MANTENIMIENTO' AND n.accion IN ('LEER', 'CREAR', 'EDITAR'))
                                         OR (n.modulo = 'DEPRECIACION' AND n.accion = 'LEER')))
   OR (r.nombre = 'CONTADOR' AND n.modulo = 'DEPRECIACION' AND n.accion IN ('LEER', 'CREAR', 'EDITAR'))
   OR (r.nombre = 'TECNICO' AND n.modulo = 'MANTENIMIENTO' AND n.accion IN ('LEER', 'CREAR', 'EDITAR'))
ON CONFLICT DO NOTHING;
