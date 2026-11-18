-- =====================================================================================
-- Sprint 3 - Migracion V4 - multiempresa real, pasarela de pagos y respaldos durables
-- Idempotente (se puede ejecutar varias veces).
--
-- 1. MULTIEMPRESA: la identidad (cuenta) es global y las membresias por empresa
--    viven en la tabla `usuario`, que ya esta particionada por empresa_id.
--    Asi una misma persona puede usar varias empresas con un solo login y
--    cambiar de empresa sin volver a autenticarse.
-- 2. PAGOS: se guarda el proveedor real y el identificador del checkout.
-- 3. RESPALDOS: el archivo tambien queda en la base (contenido BYTEA) para que
--    sobreviva a reinicios del contenedor de App Service.
-- =====================================================================================

-- ------------------------------------------------------------------ 1. Cuenta global
CREATE TABLE IF NOT EXISTS cuenta (
    id BIGSERIAL PRIMARY KEY,
    correo VARCHAR(150) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    password VARCHAR(200) NOT NULL,
    nivel VARCHAR(20) NOT NULL DEFAULT 'REGULAR'
        CHECK (nivel IN ('SUPER_ADMIN', 'ADMIN', 'REGULAR')),
    intentos_fallidos INT NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_registro TIMESTAMP NOT NULL DEFAULT now()
);

ALTER TABLE usuario ADD COLUMN IF NOT EXISTS cuenta_id BIGINT REFERENCES cuenta(id);

-- El correo deja de ser unico global: la misma persona puede tener una fila
-- en `usuario` por cada empresa en la que trabaja (membresia).
DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT conname FROM pg_constraint
             WHERE conrelid = 'usuario'::regclass AND contype = 'u'
               AND pg_get_constraintdef(oid) ILIKE '%correo%'
    LOOP
        EXECUTE format('ALTER TABLE usuario DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS uk_usuario_empresa_correo ON usuario(empresa_id, correo);

-- Cada usuario existente se convierte en la cuenta global de su correo
-- (mismo hash de contrasena, mismo nivel, mismo estado).
INSERT INTO cuenta (correo, nombre, password, nivel, intentos_fallidos, bloqueado_hasta, activo)
SELECT u.correo, u.nombre, u.password,
       CASE WHEN u.nivel IN ('SUPER_ADMIN', 'ADMIN', 'REGULAR') THEN u.nivel ELSE 'REGULAR' END,
       COALESCE(u.intentos_fallidos, 0), u.bloqueado_hasta, COALESCE(u.activo, true)
FROM usuario u
WHERE NOT EXISTS (SELECT 1 FROM cuenta c WHERE c.correo = u.correo);

UPDATE usuario u
SET cuenta_id = c.id
FROM cuenta c
WHERE c.correo = u.correo AND u.cuenta_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_usuario_cuenta ON usuario(cuenta_id);

-- ------------------------------------------------------------------ 2. Pagos reales
ALTER TABLE pago ADD COLUMN IF NOT EXISTS proveedor VARCHAR(30) NOT NULL DEFAULT 'SISTEMA';
-- Hibernate puede haber creado la columna sin valor por defecto (NOT NULL):
-- se normaliza para que los scripts de datos que no la informen no fallen.
ALTER TABLE pago ALTER COLUMN proveedor SET DEFAULT 'SISTEMA';
UPDATE pago SET proveedor = 'SISTEMA' WHERE proveedor IS NULL;
ALTER TABLE pago ADD COLUMN IF NOT EXISTS checkout_id VARCHAR(150);
ALTER TABLE pago ADD COLUMN IF NOT EXISTS fecha_aprobacion TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_pago_checkout ON pago(checkout_id);

-- ------------------------------------------------------------------ 2b. Repara depreciaciones huerfanas
-- El calculo de depreciacion con contexto de plataforma (programador o
-- arranque) dejaba las filas con empresa_id = 0 (el centinela), por lo que no
-- aparecian en los listados de la empresa y bloqueaban la restauracion de
-- respaldos. Se devuelven a la empresa de su activo.
UPDATE depreciacion_activo d
SET empresa_id = a.empresa_id
FROM activo a
WHERE a.id = d.activo_id AND d.empresa_id = 0 AND a.empresa_id IS NOT NULL;

-- ------------------------------------------------------------------ 3. Respaldos durables
ALTER TABLE respaldo ADD COLUMN IF NOT EXISTS contenido BYTEA;
COMMENT ON COLUMN respaldo.contenido IS
    'Copia del archivo de respaldo: permite descargar y restaurar aunque el disco del contenedor se reinicie.';

-- ------------------------------------------------------------------ 4. Comentarios
COMMENT ON TABLE cuenta IS
    'Identidad global de la persona (un solo login). Las membresias por empresa estan en usuario.';
COMMENT ON COLUMN usuario.cuenta_id IS
    'Cuenta global a la que pertenece esta membresia (empresa_id + rol).';
