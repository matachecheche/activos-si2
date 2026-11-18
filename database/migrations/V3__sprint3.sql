-- =====================================================================================
-- Sprint 3 (Sprint Especial) - Migracion V3 - idempotente (se puede ejecutar varias veces)
-- HU-11 SaaS multiempresa / HU-12 tres niveles / HU-13 bitacora inmutable /
-- HU-14 reportes y BI / HU-15 personalizacion / HU-16 respaldos / HU-17 inventario movil.
-- Estrategia: base de datos COMPARTIDA con empresa_id como discriminador (documento 11.8.9).
-- =====================================================================================

-- ------------------------------------------------------------------ 1. Plataforma SaaS
CREATE TABLE IF NOT EXISTS empresa (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    nit VARCHAR(30) UNIQUE,
    rubro VARCHAR(100),
    correo_contacto VARCHAR(150) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA'
        CHECK (estado IN ('ACTIVA', 'SUSPENDIDA', 'CANCELADA')),
    fecha_registro TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS plan (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    precio_mensual NUMERIC(12,2) NOT NULL,
    max_usuarios INT,                 -- NULL = ilimitado
    max_activos BIGINT,               -- NULL = ilimitado
    incluye_bi BOOLEAN NOT NULL DEFAULT false,
    incluye_consultas_dinamicas BOOLEAN NOT NULL DEFAULT false,
    respaldo_programado BOOLEAN NOT NULL DEFAULT false,
    respaldo_nube BOOLEAN NOT NULL DEFAULT false,
    idioma_adicional BOOLEAN NOT NULL DEFAULT false,
    personalizacion_completa BOOLEAN NOT NULL DEFAULT false,
    activo BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS suscripcion (
    id BIGSERIAL PRIMARY KEY,
    empresa_id BIGINT NOT NULL UNIQUE REFERENCES empresa(id) ON DELETE CASCADE,
    plan_id BIGINT NOT NULL REFERENCES plan(id),
    fecha_inicio TIMESTAMP NOT NULL DEFAULT now(),
    fecha_vencimiento TIMESTAMP NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA'
        CHECK (estado IN ('ACTIVA', 'EN_GRACIA', 'VENCIDA', 'CANCELADA')),
    fecha_estado TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pago (
    id BIGSERIAL PRIMARY KEY,
    suscripcion_id BIGINT NOT NULL REFERENCES suscripcion(id) ON DELETE CASCADE,
    monto NUMERIC(12,2) NOT NULL,
    metodo VARCHAR(30) NOT NULL,
    referencia VARCHAR(100),
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE', 'APROBADO', 'RECHAZADO')),
    detalle JSONB,
    fecha TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pago_suscripcion ON pago(suscripcion_id, fecha);

-- ------------------------------------------------------------------ 2. Bitacora inmutable (HU-13)
CREATE TABLE IF NOT EXISTS bitacora_auditoria (
    id BIGSERIAL PRIMARY KEY,
    empresa_id BIGINT,
    usuario_id BIGINT,
    usuario_nombre VARCHAR(150),
    accion VARCHAR(50) NOT NULL,
    entidad VARCHAR(80) NOT NULL,
    entidad_id VARCHAR(50),
    detalle TEXT,                      -- JSON con valores anteriores/nuevos
    ip VARCHAR(45),
    equipo VARCHAR(255),
    fecha_hora TIMESTAMP NOT NULL DEFAULT now(),
    hash_anterior VARCHAR(64),
    hash_registro VARCHAR(64) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_bitacora_empresa_fecha ON bitacora_auditoria (empresa_id, fecha_hora);
CREATE INDEX IF NOT EXISTS idx_bitacora_usuario ON bitacora_auditoria (usuario_id);
CREATE INDEX IF NOT EXISTS idx_bitacora_entidad ON bitacora_auditoria (entidad, entidad_id);
CREATE INDEX IF NOT EXISTS idx_bitacora_accion ON bitacora_auditoria (accion);

-- Trigger que rechaza UPDATE y DELETE: la bitacora es caja negra (CP-23).
CREATE OR REPLACE FUNCTION bitacora_inmutable_fn() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'La bitacora de auditoria es inmutable: operacion % rechazada', TG_OP;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bitacora_bloqueo ON bitacora_auditoria;
CREATE TRIGGER trg_bitacora_bloqueo
    BEFORE UPDATE OR DELETE OR TRUNCATE ON bitacora_auditoria
    FOR EACH STATEMENT EXECUTE FUNCTION bitacora_inmutable_fn();
REVOKE UPDATE, DELETE, TRUNCATE ON bitacora_auditoria FROM PUBLIC;

-- ------------------------------------------------------------------ 3. Personalizacion (HU-15)
CREATE TABLE IF NOT EXISTS configuracion_empresa (
    id BIGSERIAL PRIMARY KEY,
    empresa_id BIGINT NOT NULL UNIQUE REFERENCES empresa(id) ON DELETE CASCADE,
    color_primario VARCHAR(20) NOT NULL DEFAULT '#2c5cc5',
    color_secundario VARCHAR(20) NOT NULL DEFAULT '#0f2a5c',
    logo BYTEA,
    logo_nombre VARCHAR(200),
    logo_tipo VARCHAR(100),
    idioma VARCHAR(5) NOT NULL DEFAULT 'es' CHECK (idioma IN ('es', 'en')),
    menu_config JSONB NOT NULL DEFAULT '[]'::jsonb
);

-- ------------------------------------------------------------------ 4. Respaldos (HU-16)
CREATE TABLE IF NOT EXISTS respaldo (
    id BIGSERIAL PRIMARY KEY,
    empresa_id BIGINT,                      -- NULL = respaldo completo de la plataforma
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('MANUAL', 'PROGRAMADO', 'PLATAFORMA', 'SEGURIDAD')),
    destino VARCHAR(20) NOT NULL DEFAULT 'LOCAL' CHECK (destino IN ('LOCAL', 'NUBE')),
    archivo VARCHAR(255) NOT NULL,
    tamano_bytes BIGINT NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'COMPLETADO' CHECK (estado IN ('COMPLETADO', 'FALLIDO', 'RESTAURADO')),
    usuario_id BIGINT,
    fecha TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_respaldo_empresa ON respaldo(empresa_id, fecha);

CREATE TABLE IF NOT EXISTS programacion_respaldo (
    id BIGSERIAL PRIMARY KEY,
    empresa_id BIGINT NOT NULL UNIQUE REFERENCES empresa(id) ON DELETE CASCADE,
    frecuencia VARCHAR(10) NOT NULL CHECK (frecuencia IN ('DIARIA', 'SEMANAL')),
    hora VARCHAR(5) NOT NULL DEFAULT '02:00',
    copias_a_conservar INT NOT NULL DEFAULT 3,
    destino VARCHAR(20) NOT NULL DEFAULT 'LOCAL',
    activa BOOLEAN NOT NULL DEFAULT true
);

-- ------------------------------------------------------------------ 5. Consultas guardadas (HU-14)
CREATE TABLE IF NOT EXISTS consulta_guardada (
    id BIGSERIAL PRIMARY KEY,
    empresa_id BIGINT NOT NULL,
    usuario_id BIGINT,
    nombre VARCHAR(150) NOT NULL,
    entidad VARCHAR(80) NOT NULL,
    definicion JSONB NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_consulta_guardada_empresa ON consulta_guardada(empresa_id);

-- ------------------------------------------------------------------ 6. Inventario movil (HU-17)
CREATE TABLE IF NOT EXISTS verificacion_inventario (
    id BIGSERIAL PRIMARY KEY,
    empresa_id BIGINT NOT NULL,
    activo_id BIGINT NOT NULL,
    usuario_id BIGINT,
    fecha_hora TIMESTAMP NOT NULL DEFAULT now(),
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    precision_m DOUBLE PRECISION,
    resultado VARCHAR(25) NOT NULL
        CHECK (resultado IN ('ENCONTRADO', 'NO_ENCONTRADO', 'DIFERENCIA_ESTADO')),
    foto_url VARCHAR(500),
    observacion VARCHAR(500)
);
CREATE INDEX IF NOT EXISTS idx_verificacion_activo ON verificacion_inventario(activo_id, fecha_hora);

-- ------------------------------------------------------------------ 7. empresa_id en tablas de negocio
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS empresa_id BIGINT REFERENCES empresa(id);
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS nivel VARCHAR(20) NOT NULL DEFAULT 'REGULAR'
    CHECK (nivel IN ('SUPER_ADMIN', 'ADMIN', 'REGULAR'));
ALTER TABLE rol ADD COLUMN IF NOT EXISTS empresa_id BIGINT REFERENCES empresa(id);
ALTER TABLE rol ADD COLUMN IF NOT EXISTS es_sistema BOOLEAN NOT NULL DEFAULT false;

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'activo', 'categoria', 'ubicacion', 'area', 'asignacion',
        'historial_estado_activo', 'depreciacion_activo', 'mantenimiento',
        'presupuesto', 'partida_presupuestaria', 'ejecucion_presupuestaria']
    LOOP
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS empresa_id BIGINT', t);
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_empresa ON %I(empresa_id)', t, t);
    END LOOP;
END $$;

-- HU-17: foto del activo (camara del movil)
ALTER TABLE activo ADD COLUMN IF NOT EXISTS foto_url VARCHAR(500);

-- ------------------------------------------------------------------ 8. Empresa semilla y migracion de datos existentes
-- Empresa PLATAFORMA con id 0: es el centinela ROOT de TenantResolver (sin ella,
-- Hibernate escribe empresa_id=0 en el rol/usuario del Super Admin y la llave
-- foranea rol_empresa_id_fkey / usuario_empresa_id_fkey rechaza la insercion).
-- El panel SaaS nunca la lista (EmpresaAdminService filtra id > 0) y la secuencia
-- se reposiciona para que las empresas reales empiecen en id 1.
INSERT INTO empresa (id, nombre, nit, rubro, correo_contacto, estado, fecha_registro)
SELECT 0, 'Plataforma SaaS (super administracion)', 'PLATAFORMA-0', 'Plataforma', 'plataforma@local', 'ACTIVA', now()
WHERE NOT EXISTS (SELECT 1 FROM empresa WHERE id = 0);

INSERT INTO empresa (id, nombre, nit, rubro, correo_contacto, estado, fecha_registro)
SELECT 1, 'Empresa Demo UAGRM', '1000001000', 'Educacion superior', 'admin@uagrm.edu.bo', 'ACTIVA', now()
WHERE NOT EXISTS (SELECT 1 FROM empresa WHERE id = 1);
SELECT setval(pg_get_serial_sequence('empresa', 'id'), GREATEST((SELECT MAX(id) FROM empresa), 1));

-- En una base recien reseteada, Hibernate (ddl-auto=update) puede crear la columna
-- nivel antes que esta migracion, sin valor por defecto y con filas en NULL:
-- se normaliza primero para que los filtros siguientes sean a prueba de NULL.
UPDATE usuario SET nivel = 'REGULAR' WHERE nivel IS NULL;
ALTER TABLE usuario ALTER COLUMN nivel SET DEFAULT 'REGULAR';
ALTER TABLE usuario ALTER COLUMN nivel SET NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'usuario'::regclass
                   AND conname = 'chk_usuario_nivel') THEN
        ALTER TABLE usuario ADD CONSTRAINT chk_usuario_nivel
            CHECK (nivel IN ('SUPER_ADMIN', 'ADMIN', 'REGULAR'));
    END IF;
END $$;

-- Toda la data previa al Sprint 3 pertenece a la empresa demo (id 1).
-- El Super Admin de plataforma y su rol cuelgan de la empresa centinela id 0
-- (TenantResolver.ROOT); el resto de datos migra a la empresa demo.
-- COALESCE hace los filtros inmunes a niveles todavia no poblados.
UPDATE usuario SET empresa_id = 0 WHERE empresa_id IS NULL AND COALESCE(nivel, 'REGULAR') = 'SUPER_ADMIN';
UPDATE rol SET empresa_id = 0 WHERE empresa_id IS NULL AND nombre = 'SUPER_ADMIN';
UPDATE usuario SET empresa_id = 1 WHERE empresa_id IS NULL AND COALESCE(nivel, 'REGULAR') <> 'SUPER_ADMIN';
UPDATE rol SET empresa_id = 1 WHERE empresa_id IS NULL AND nombre <> 'SUPER_ADMIN';
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'activo', 'categoria', 'ubicacion', 'area', 'asignacion',
        'historial_estado_activo', 'depreciacion_activo', 'mantenimiento',
        'presupuesto', 'partida_presupuestaria', 'ejecucion_presupuestaria',
        'consulta_guardada', 'verificacion_inventario']
    LOOP
        EXECUTE format('UPDATE %I SET empresa_id = 1 WHERE empresa_id IS NULL', t);
    END LOOP;
END $$;
-- usuario/rol admiten NULL: filas de plataforma
ALTER TABLE usuario ALTER COLUMN empresa_id DROP NOT NULL;
ALTER TABLE rol ALTER COLUMN empresa_id DROP NOT NULL;

UPDATE usuario SET nivel = 'ADMIN'
WHERE nivel = 'REGULAR' AND rol_id = (SELECT id FROM rol WHERE nombre = 'ADMINISTRADOR' LIMIT 1);
UPDATE rol SET es_sistema = true WHERE empresa_id = 1;

-- Unicidad por empresa (se reemplazan las restricciones globales del Sprint 1/2)
DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT conname FROM pg_constraint
             WHERE conrelid = 'activo'::regclass AND contype = 'u'
               AND pg_get_constraintdef(oid) ILIKE '%codigo%'
    LOOP
        EXECUTE format('ALTER TABLE activo DROP CONSTRAINT %I', r.conname);
    END LOOP;
    FOR r IN SELECT conname FROM pg_constraint
             WHERE conrelid = 'categoria'::regclass AND contype = 'u'
               AND pg_get_constraintdef(oid) ILIKE '%nombre%'
    LOOP
        EXECUTE format('ALTER TABLE categoria DROP CONSTRAINT %I', r.conname);
    END LOOP;
    FOR r IN SELECT conname FROM pg_constraint
             WHERE conrelid = 'rol'::regclass AND contype = 'u'
               AND pg_get_constraintdef(oid) ILIKE '%nombre%'
    LOOP
        EXECUTE format('ALTER TABLE rol DROP CONSTRAINT %I', r.conname);
    END LOOP;
    FOR r IN SELECT conname FROM pg_constraint
             WHERE conrelid = 'area'::regclass AND contype = 'u'
               AND pg_get_constraintdef(oid) ILIKE '%nombre%'
    LOOP
        EXECUTE format('ALTER TABLE area DROP CONSTRAINT %I', r.conname);
    END LOOP;
    FOR r IN SELECT conname FROM pg_constraint
             WHERE conrelid = 'presupuesto'::regclass AND contype = 'u'
    LOOP
        EXECUTE format('ALTER TABLE presupuesto DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uk_activo_empresa_codigo ON activo(empresa_id, codigo);
CREATE UNIQUE INDEX IF NOT EXISTS uk_categoria_empresa_nombre ON categoria(empresa_id, nombre);
CREATE UNIQUE INDEX IF NOT EXISTS uk_rol_empresa_nombre ON rol(empresa_id, nombre);
CREATE UNIQUE INDEX IF NOT EXISTS uk_area_empresa_nombre ON area(empresa_id, nombre);
CREATE UNIQUE INDEX IF NOT EXISTS uk_presupuesto_empresa_area_gestion
    ON presupuesto(empresa_id, area_id, gestion);

-- ------------------------------------------------------------------ 9. Planes (11.8.8)
INSERT INTO plan (nombre, precio_mensual, max_usuarios, max_activos, incluye_bi,
                  incluye_consultas_dinamicas, respaldo_programado, respaldo_nube,
                  idioma_adicional, personalizacion_completa, activo)
SELECT * FROM (VALUES
    ('Basico', 400.00, 10, 500, false, false, false, false, false, false, true),
    ('Profesional', 700.00, 25, 3000, true, true, true, false, true, false, true),
    ('Empresarial', 1000.00, 100, NULL, true, true, true, true, true, true, true)
) AS v(nombre, precio_mensual, max_usuarios, max_activos, incluye_bi,
       incluye_consultas_dinamicas, respaldo_programado, respaldo_nube,
       idioma_adicional, personalizacion_completa, activo)
WHERE NOT EXISTS (SELECT 1 FROM plan p WHERE p.nombre = v.nombre);

-- Suscripcion activa de la empresa demo (plan Empresarial: habilita todas las funciones)
INSERT INTO suscripcion (empresa_id, plan_id, fecha_inicio, fecha_vencimiento, estado, fecha_estado)
SELECT 1, p.id, now(), now() + INTERVAL '12 months', 'ACTIVA', now()
FROM plan p WHERE p.nombre = 'Empresarial'
  AND NOT EXISTS (SELECT 1 FROM suscripcion s WHERE s.empresa_id = 1);

-- Configuracion por defecto de la empresa demo
INSERT INTO configuracion_empresa (empresa_id, color_primario, color_secundario, idioma, menu_config)
SELECT 1, '#2c5cc5', '#0f2a5c', 'es', '[]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM configuracion_empresa WHERE empresa_id = 1);

-- ------------------------------------------------------------------ 10. Permisos del Sprint 3
INSERT INTO permiso (modulo, accion, descripcion)
SELECT * FROM (VALUES
    ('SUSCRIPCION', 'LEER', 'Ver la suscripcion y el plan de la empresa'),
    ('SUSCRIPCION', 'EDITAR', 'Registrar pagos y renovar o cambiar de plan'),
    ('AUDITORIA', 'LEER', 'Consultar la bitacora de auditoria y verificar su integridad'),
    ('RESPALDO', 'GESTIONAR', 'Generar, descargar, programar y restaurar respaldos'),
    ('CONFIG_EMPRESA', 'LEER', 'Ver la personalizacion de la empresa'),
    ('CONFIG_EMPRESA', 'EDITAR', 'Cambiar colores, logotipo, idioma y menu'),
    ('IA', 'CONSULTAR', 'Usar el asistente de consultas con inteligencia artificial'),
    ('INVENTARIO', 'LEER', 'Consultar verificaciones de inventario y estadisticas'),
    ('INVENTARIO', 'VERIFICAR', 'Registrar verificaciones de inventario con GPS y fotos')
) AS v(modulo, accion, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM permiso p WHERE p.modulo = v.modulo AND p.accion = v.accion);

-- El ADMINISTRADOR de la empresa demo hereda todos los permisos nuevos
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id
FROM rol r CROSS JOIN permiso p
WHERE r.empresa_id = 1 AND r.nombre = 'ADMINISTRADOR'
  AND p.modulo IN ('SUSCRIPCION', 'AUDITORIA', 'RESPALDO', 'CONFIG_EMPRESA', 'IA', 'INVENTARIO')
  AND NOT EXISTS (
      SELECT 1 FROM rol_permiso rp WHERE rp.rol_id = r.id AND rp.permiso_id = p.id);

-- ------------------------------------------------------------------ 11. Comentarios
COMMENT ON TABLE bitacora_auditoria IS 'HU-13: solo INSERT/SELECT. El trigger rechaza UPDATE/DELETE/TRUNCATE.';
COMMENT ON TABLE empresa IS 'HU-11: cliente SaaS. Toda tabla de negocio se aísla por empresa_id.';
COMMENT ON TABLE plan IS 'HU-11: limites y funciones habilitadas; editables sin tocar codigo.';
