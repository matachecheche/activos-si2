-- Datos de prueba del Sprint 2 (opcional). Ejecutar despues de iniciar el backend al menos una vez
-- (crea las areas, categorias parametrizadas y permisos). Es idempotente.
--   psql -U postgres -d activos_fijos_db -f database/seed_sprint2_datos.sql
-- Sprint 3: todas las tablas de negocio son multiempresa (empresa_id NOT NULL).
-- La migracion V3 crea la "Empresa Demo UAGRM" con id = 1; estos datos se cargan en ella.
--
-- IMPORTANTE (arreglo del despliegue en la nube): los INSERT ... SELECT de este
-- archivo dependen de que existan las areas. Si el seed corre antes de que el
-- backend termine su inicializacion (la tabla "area" todavia vacia), el script
-- TERMINA "CON EXITO" pero sin insertar ninguna fila: los presupuestos y las
-- partidas quedan vacios y luego el seed del Sprint 3 revienta con
-- "null value in column partida_id". Por eso el bloque de mas abajo garantiza
-- las areas de la empresa demo antes de sembrar los presupuestos.

-- Las areas de la empresa demo (id 1). Si la tabla "area" todavia no existe
-- (el backend no ha iniciado) se omite el bloque: el propio backend las crea.
DO $$
DECLARE
    hay_empresa BOOLEAN;
BEGIN
    IF to_regclass('public.area') IS NULL THEN
        RAISE NOTICE 'La tabla area todavia no existe; se omite la siembra de areas.';
        RETURN;
    END IF;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'area'
                     AND column_name = 'empresa_id')
      INTO hay_empresa;
    IF hay_empresa THEN
        INSERT INTO area (nombre, descripcion, activo, empresa_id)
        SELECT v.nombre, v.descripcion, TRUE, 1
        FROM (VALUES
            ('Dirección administrativa', 'Administración general de la facultad'),
            ('Sistemas', 'Infraestructura y soporte informático'),
            ('Laboratorios', 'Laboratorios de redes y cómputo'),
            ('Biblioteca', 'Biblioteca y centro de documentación'),
            ('Almacén', 'Almacén central de bienes')
        ) AS v(nombre, descripcion)
        WHERE NOT EXISTS (SELECT 1 FROM area a WHERE a.nombre = v.nombre);
    ELSE
        INSERT INTO area (nombre, descripcion, activo)
        SELECT v.nombre, v.descripcion, TRUE
        FROM (VALUES
            ('Dirección administrativa', 'Administración general de la facultad'),
            ('Sistemas', 'Infraestructura y soporte informático'),
            ('Laboratorios', 'Laboratorios de redes y cómputo'),
            ('Biblioteca', 'Biblioteca y centro de documentación'),
            ('Almacén', 'Almacén central de bienes')
        ) AS v(nombre, descripcion)
        WHERE NOT EXISTS (SELECT 1 FROM area a WHERE a.nombre = v.nombre);
    END IF;
END $$;

-- Ubicaciones asociadas a un area
UPDATE ubicacion SET area_id = (SELECT id FROM area WHERE nombre = 'Laboratorios') WHERE area_id IS NULL AND nombre ILIKE '%lab%';
UPDATE ubicacion SET area_id = (SELECT id FROM area WHERE nombre = 'Sistemas') WHERE area_id IS NULL AND nombre ILIKE '%sistem%';

-- Presupuesto 2026 del area Sistemas (aprobado) con dos partidas
INSERT INTO presupuesto (empresa_id, area_id, gestion, monto_aprobado, estado, fecha_aprobacion, usuario_aprobador_id)
SELECT 1, a.id, 2026, 100000.00, 'APROBADO', NOW(), (SELECT u.id FROM usuario u JOIN rol r ON r.id = u.rol_id WHERE r.nombre = 'ADMINISTRADOR' ORDER BY u.id LIMIT 1)
FROM area a WHERE a.nombre = 'Sistemas'
ON CONFLICT (empresa_id, area_id, gestion) DO NOTHING;

INSERT INTO partida_presupuestaria (empresa_id, presupuesto_id, codigo, nombre, monto_planificado)
SELECT 1, p.id, v.codigo, v.nombre, v.monto
FROM presupuesto p JOIN area a ON a.id = p.area_id AND a.nombre = 'Sistemas' AND p.gestion = 2026
CROSS JOIN (VALUES ('43100', 'Equipos de computación', 60000.00), ('43200', 'Mobiliario y enseres', 30000.00)) AS v(codigo, nombre, monto)
ON CONFLICT (presupuesto_id, codigo) DO NOTHING;

-- Presupuesto 2026 del area Laboratorios en borrador
INSERT INTO presupuesto (empresa_id, area_id, gestion, monto_aprobado, estado)
SELECT 1, a.id, 2026, 40000.00, 'BORRADOR' FROM area a WHERE a.nombre = 'Laboratorios'
ON CONFLICT (empresa_id, area_id, gestion) DO NOTHING;

-- Un mantenimiento preventivo para el primer activo (vence en 5 dias)
INSERT INTO mantenimiento (empresa_id, activo_id, tipo, estado, descripcion, fecha_programada, periodicidad_dias, fecha_creacion)
SELECT 1, a.id, 'PREVENTIVO', 'PROGRAMADO', 'Limpieza y revisión general', CURRENT_DATE + 5, 90, NOW()
FROM activo a
WHERE a.estado IN ('DISPONIBLE', 'EN_USO')
  AND NOT EXISTS (SELECT 1 FROM mantenimiento m WHERE m.descripcion = 'Limpieza y revisión general')
ORDER BY a.id LIMIT 1;
