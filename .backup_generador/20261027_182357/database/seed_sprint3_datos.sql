-- ============================================================================
-- seed_sprint3_datos.sql
-- Datos ficticios DE FABRICA del Sprint 3: rellena TODAS las tablas de negocio
-- que quedaban vacias despues de un reseteo total (pagos de suscripcion,
-- ejecuciones presupuestarias, historial de estados, mantenimientos,
-- verificaciones de inventario, consultas guardadas, respaldos, programacion
-- de respaldos y bitacora de auditoria), y amplia las asignaciones.
--
-- Requisitos: ejecutarse DESPUES de que el backend arranco una vez (la
-- migracion V3 ya creo las tablas, las areas, los planes y la empresa demo
-- id = 1). Todos los datos pertenecen a la empresa demo (empresa_id = 1).
--
-- Es idempotente: puede ejecutarse varias veces sin duplicar nada (guarda
-- por claves naturales y marcadores [demo]).
--
-- ROBUSTEZ (arreglo del despliegue en la nube): este archivo se ejecuta dentro
-- de una transaccion implicita cuando el ejecutor manda el script entero. Si
-- una sola sentencia falla (por ejemplo una partida presupuestaria que aun no
-- existe), PostgreSQL revierte TODO el archivo y la aplicacion queda sin datos
-- de Sprint 3. Por eso aqui se tolera la falta de datos previa: se crean las
-- areas y las partidas que falten y se omiten las filas que no se pueden
-- armar, en vez de abortar la carga completa.
-- ============================================================================

-- ---------------------------------------------------------------- 0. pgcrypto
-- La bitacora necesita SHA-256 para encadenar sus hashes. pgcrypto es una
-- extension confiable (la puede instalar el dueno de la base, incluso en
-- Neon). Si no se puede instalar, la bitacora y los sha de respaldo usan
-- alternativas sin extension; el resto de los datos se carga igual.
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgcrypto no disponible (%), se usaran alternativas sin extension.', SQLERRM;
END $$;

-- ------------------------------------------------- 1. Mas asignaciones de activos
-- Los dos primeros ya vienen asignados desde seed_datos_ficticios.sql; aqui
-- se asignan cinco activos mas, todos con su registro de asignacion activa y
-- la actualizacion del estado del activo a EN_USO.
DO $$
DECLARE
    v_admin       INT;
    v_encargado   INT;
    v_financiero  INT;
    v_oficina     INT;
    v_almacen     INT;
    v_direccion   INT;
    v_activo      INT;
    v_responsable INT;
    v_ubicacion   INT;
    r             RECORD;
BEGIN
    SELECT id INTO v_admin      FROM usuario WHERE correo = 'admin@uagrm.edu.bo';
    SELECT id INTO v_encargado  FROM usuario WHERE correo = 'encargado@uagrm.edu.bo';
    SELECT id INTO v_financiero FROM usuario WHERE correo = 'financiero@uagrm.edu.bo';
    SELECT id INTO v_oficina    FROM ubicacion WHERE nombre = 'Oficina de sistemas';
    SELECT id INTO v_almacen    FROM ubicacion WHERE nombre = 'Almacen central';
    SELECT id INTO v_direccion  FROM ubicacion WHERE nombre = 'Direccion administrativa';

    FOR r IN
        SELECT codigo, responsable, ubicacion FROM (VALUES
            ('ACT-2026-0002', v_admin,      v_oficina),
            ('ACT-2026-0003', v_encargado,  v_almacen),
            ('ACT-2026-0007', v_financiero, v_almacen),
            ('ACT-2026-0008', v_admin,      v_direccion),
            ('ACT-2026-0011', v_financiero, v_direccion)
        ) AS t(codigo, responsable, ubicacion)
    LOOP
        SELECT id INTO v_activo FROM activo WHERE codigo = r.codigo;
        IF v_activo IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM asignacion WHERE activo_id = v_activo AND activa = TRUE) THEN
            INSERT INTO asignacion (empresa_id, activo_id, responsable_id, ubicacion_id, fecha_asignacion, activa)
            VALUES (1, v_activo, r.responsable, r.ubicacion, TIMESTAMP '2026-02-01 09:00:00', TRUE);
            UPDATE activo
               SET responsable_id = r.responsable,
                   ubicacion_id   = r.ubicacion,
                   estado         = 'EN_USO'
             WHERE id = v_activo;
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 2. Historial de estados
-- Un registro inicial por cada activo y, segun su estado actual, los cambios
-- de estado reales (asignacion, mantenimiento, baja).
DO $$
DECLARE
    a           RECORD;
    v_admin     INT;
    v_encargado INT;
BEGIN
    SELECT id INTO v_admin     FROM usuario WHERE correo = 'admin@uagrm.edu.bo';
    SELECT id INTO v_encargado FROM usuario WHERE correo = 'encargado@uagrm.edu.bo';

    FOR a IN SELECT id, estado, fecha_adquisicion FROM activo WHERE empresa_id = 1 ORDER BY id LOOP
        -- Registro inicial (todos los activos)
        IF NOT EXISTS (SELECT 1 FROM historial_estado_activo
                       WHERE activo_id = a.id AND motivo = 'Registro inicial del activo (dato de fabrica)') THEN
            INSERT INTO historial_estado_activo
                (empresa_id, activo_id, estado_anterior, estado_nuevo, motivo, usuario_id, fecha)
            VALUES
                (1, a.id, NULL, 'DISPONIBLE', 'Registro inicial del activo (dato de fabrica)',
                 v_admin, a.fecha_adquisicion::timestamp + TIME '09:00:00');
        END IF;

        -- Activos en uso: pase por asignacion
        IF a.estado = 'EN_USO'
           AND NOT EXISTS (SELECT 1 FROM historial_estado_activo
                           WHERE activo_id = a.id AND estado_nuevo = 'EN_USO') THEN
            INSERT INTO historial_estado_activo
                (empresa_id, activo_id, estado_anterior, estado_nuevo, motivo, usuario_id, fecha)
            VALUES
                (1, a.id, 'DISPONIBLE', 'EN_USO',
                 'Asignacion de responsable mediante el modulo de activos (dato de fabrica)',
                 v_admin, TIMESTAMP '2026-02-01 09:00:00');
        END IF;

        -- Activo en mantenimiento
        IF a.estado = 'EN_MANTENIMIENTO'
           AND NOT EXISTS (SELECT 1 FROM historial_estado_activo
                           WHERE activo_id = a.id AND estado_nuevo = 'EN_MANTENIMIENTO') THEN
            INSERT INTO historial_estado_activo
                (empresa_id, activo_id, estado_anterior, estado_nuevo, motivo, usuario_id, fecha)
            VALUES
                (1, a.id, 'DISPONIBLE', 'EN_MANTENIMIENTO',
                 'Pase a mantenimiento correctivo por falla reportada (dato de fabrica)',
                 v_encargado, TIMESTAMP '2026-10-22 10:30:00');
        END IF;

        -- Activo dado de baja
        IF a.estado = 'DADO_DE_BAJA'
           AND NOT EXISTS (SELECT 1 FROM historial_estado_activo
                           WHERE activo_id = a.id AND estado_nuevo = 'DADO_DE_BAJA') THEN
            INSERT INTO historial_estado_activo
                (empresa_id, activo_id, estado_anterior, estado_nuevo, motivo, usuario_id, fecha)
            VALUES
                (1, a.id, 'DISPONIBLE', 'DADO_DE_BAJA',
                 'Retiro por desgaste mecanico y obsolescencia (dato de fabrica)',
                 v_admin, TIMESTAMP '2026-09-15 16:00:00');
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 3. Mantenimientos de ejemplo
-- Cubre los cuatro estados y los dos tipos, con costos, tecnicos y fechas.
DO $$
DECLARE
    v_admin     INT;
    v_encargado INT;
    m           RECORD;
BEGIN
    SELECT id INTO v_admin     FROM usuario WHERE correo = 'admin@uagrm.edu.bo';
    SELECT id INTO v_encargado FROM usuario WHERE correo = 'encargado@uagrm.edu.bo';

    FOR m IN
        SELECT * FROM (VALUES
            ('ACT-2026-0001', 'PREVENTIVO', 'FINALIZADO',
             'Limpieza general y cambio de pasta termica (dato de fabrica)',
             DATE '2026-04-08', DATE '2026-04-10', NULL, 350.00,
             'ServiTech SRL', 90, TIMESTAMP '2026-04-01 08:30:00', NULL, 'EN_USO'),
            ('ACT-2026-0003', 'CORRECTIVO', 'FINALIZADO',
             'Cambio de cabezal de impresion y limpieza de inyectores (dato de fabrica)',
             DATE '2026-05-12', DATE '2026-05-13', NULL, 480.00,
             'Comercial Andina', NULL, TIMESTAMP '2026-05-10 14:00:00', NULL, 'DISPONIBLE'),
            ('ACT-2026-0004', 'CORRECTIVO', 'EN_EJECUCION',
             'Reemplazo de lampara y revision de la fuente (dato de fabrica)',
             DATE '2026-10-20', NULL, TIMESTAMP '2026-10-22 09:00:00', NULL,
             'ClimaTech', NULL, TIMESTAMP '2026-10-19 17:00:00', TIMESTAMP '2026-10-22 09:00:00', 'DISPONIBLE'),
            ('ACT-2026-0008', 'PREVENTIVO', 'PROGRAMADO',
             'Servicio de control de los 10.000 km (dato de fabrica)',
             DATE '2026-11-15', NULL, NULL, NULL,
             'Toyotasa', 180, TIMESTAMP '2026-10-20 11:00:00', NULL, NULL),
            ('ACT-2026-0010', 'PREVENTIVO', 'FINALIZADO',
             'Cambio de aceite y filtros del generador (dato de fabrica)',
             DATE '2026-06-18', DATE '2026-06-19', NULL, 260.00,
             'Ferreteria Central', 120, TIMESTAMP '2026-06-15 10:00:00', NULL, 'DISPONIBLE'),
            ('ACT-2026-0011', 'CORRECTIVO', 'CANCELADO',
             'Recarga de gas refrigerante, reprogramado para el siguiente mes (dato de fabrica)',
             DATE '2026-09-30', NULL, NULL, NULL,
             'ClimaTech', NULL, TIMESTAMP '2026-09-25 09:30:00', NULL, NULL)
        ) AS t(codigo, tipo, estado, descripcion, f_programada, f_realizada,
               f_inicio, costo, tecnico, periodicidad, f_creacion, f_inicio_ts, estado_previo)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM mantenimiento WHERE descripcion = m.descripcion) THEN
            INSERT INTO mantenimiento (
                empresa_id, activo_id, tipo, estado, descripcion, fecha_programada,
                periodicidad_dias, fecha_inicio, fecha_realizada, costo, tecnico,
                observaciones, estado_previo_activo, fecha_creacion, creado_por_id)
            SELECT 1, a.id, m.tipo, m.estado, m.descripcion, m.f_programada,
                   m.periodicidad, COALESCE(m.f_inicio_ts, m.f_inicio), m.f_realizada, m.costo,
                   m.tecnico, 'Trabajo registrado como dato de fabrica para la demo.',
                   m.estado_previo, m.f_creacion,
                   CASE WHEN m.tipo = 'PREVENTIVO' THEN v_encargado ELSE v_admin END
              FROM activo a WHERE a.codigo = m.codigo;
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 4. Presupuesto y partidas adicionales
-- Las areas de la empresa demo son el prerrequisito de los presupuestos: si el
-- backend aun no termino su inicializacion la tabla "area" esta vacia y los
-- INSERT ... SELECT de abajo no insertarian nada (el script "terminaria bien"
-- pero sin datos). Aqui se aseguran las areas y las partidas de los dos
-- presupuestos de demostracion, de modo que el archivo sea autocontenido.
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

-- Presupuesto aprobado del area Direccion administrativa con dos partidas.
INSERT INTO presupuesto (empresa_id, area_id, gestion, monto_aprobado, estado,
                         fecha_aprobacion, usuario_aprobador_id)
SELECT 1, ar.id, 2026, 50000.00, 'APROBADO', TIMESTAMP '2026-01-05 10:00:00',
       (SELECT id FROM usuario WHERE correo = 'admin@uagrm.edu.bo')
  FROM area ar
 WHERE ar.nombre = 'Dirección administrativa'
   AND NOT EXISTS (SELECT 1 FROM presupuesto p
                   WHERE p.empresa_id = 1 AND p.area_id = ar.id AND p.gestion = 2026);

INSERT INTO partida_presupuestaria (empresa_id, presupuesto_id, codigo, nombre, monto_planificado)
SELECT 1, p.id, v.codigo, v.nombre, v.monto
  FROM presupuesto p
  JOIN area ar ON ar.id = p.area_id AND ar.nombre = 'Dirección administrativa' AND p.gestion = 2026
 CROSS JOIN (VALUES
     ('43300', 'Mantenimiento de instalaciones', 20000.00),
     ('43400', 'Equipos de oficina', 15000.00)
 ) AS v(codigo, nombre, monto)
ON CONFLICT (presupuesto_id, codigo) DO NOTHING;

-- Las partidas del presupuesto de Sistemas (las usa el seed del Sprint 2 y las
-- ejecuciones de mas abajo). Se aseguran aqui para que este archivo tambien
-- funcione por sí solo, aunque el seed del Sprint 2 todavia no se haya aplicado.
INSERT INTO presupuesto (empresa_id, area_id, gestion, monto_aprobado, estado,
                         fecha_aprobacion, usuario_aprobador_id)
SELECT 1, a.id, 2026, 100000.00, 'APROBADO', NOW(),
       (SELECT id FROM usuario WHERE correo = 'admin@uagrm.edu.bo')
  FROM area a
 WHERE a.nombre = 'Sistemas'
   AND NOT EXISTS (SELECT 1 FROM presupuesto p
                   WHERE p.empresa_id = 1 AND p.area_id = a.id AND p.gestion = 2026);

INSERT INTO partida_presupuestaria (empresa_id, presupuesto_id, codigo, nombre, monto_planificado)
SELECT 1, p.id, v.codigo, v.nombre, v.monto
  FROM presupuesto p
  JOIN area a ON a.id = p.area_id AND a.nombre = 'Sistemas' AND p.gestion = 2026
 CROSS JOIN (VALUES
     ('43100', 'Equipos de computación', 60000.00),
     ('43200', 'Mobiliario y enseres', 30000.00)
 ) AS v(codigo, nombre, monto)
ON CONFLICT (presupuesto_id, codigo) DO NOTHING;

-- ------------------------------------------------- 5. Ejecucion presupuestaria
-- Compromisos (pedidos) y sus ejecuciones (pagos), varios ligados a los
-- activos adquiridos. Los montos nunca superan lo planificado en la partida.
DO $$
DECLARE
    v_financiero INT;
    v_part_eq    INT;  -- 43100 Equipos de computacion
    v_part_mob   INT;  -- 43200 Mobiliario y enseres
    v_part_inst  INT;  -- 43300 Mantenimiento de instalaciones
    v_comp       INT;
    e            RECORD;
BEGIN
    SELECT id INTO v_financiero FROM usuario WHERE correo = 'financiero@uagrm.edu.bo';
    SELECT pp.id INTO v_part_eq
      FROM partida_presupuestaria pp JOIN presupuesto p ON p.id = pp.presupuesto_id
     WHERE pp.codigo = '43100' AND p.gestion = 2026;
    SELECT pp.id INTO v_part_mob
      FROM partida_presupuestaria pp JOIN presupuesto p ON p.id = pp.presupuesto_id
     WHERE pp.codigo = '43200' AND p.gestion = 2026;
    SELECT pp.id INTO v_part_inst
      FROM partida_presupuestaria pp JOIN presupuesto p ON p.id = pp.presupuesto_id
     WHERE pp.codigo = '43300' AND p.gestion = 2026;

    -- Tabla temporal de trabajo: compromisos y ejecuciones en orden.
    CREATE TEMP TABLE IF NOT EXISTS tmp_seed_ejecuciones (
        ord          INT,
        es_compromiso BOOLEAN,
        concepto     VARCHAR(200),
        monto        NUMERIC(14,2),
        fecha        DATE,
        partida      INT,
        codigo_activo VARCHAR(30),
        clave_compromiso VARCHAR(120)
    ) ON COMMIT DROP;

    INSERT INTO tmp_seed_ejecuciones VALUES
        (1, TRUE,  'Pedido SC-001: laptops para el area de Sistemas (dato de fabrica)', 17000.00, DATE '2026-01-10', v_part_eq,  NULL, 'C1'),
        (2, FALSE, 'Pago laptop Dell Latitude ACT-2026-0001 (dato de fabrica)',         8500.00, DATE '2026-01-15', v_part_eq,  'ACT-2026-0001', 'C1'),
        (3, FALSE, 'Pago laptop HP ProBook ACT-2026-0002 (dato de fabrica)',            7900.00, DATE '2026-01-15', v_part_eq,  'ACT-2026-0002', 'C1'),
        (4, TRUE,  'Pedido SC-002: impresora multifuncional (dato de fabrica)',          2500.00, DATE '2026-01-28', v_part_eq,  NULL, 'C2'),
        (5, FALSE, 'Compra impresora Epson L5590 ACT-2026-0003 (dato de fabrica)',       2300.00, DATE '2026-02-02', v_part_eq,  'ACT-2026-0003', 'C2'),
        (6, FALSE, 'Compra proyector Epson PowerLite ACT-2026-0004 (dato de fabrica)',   3200.00, DATE '2026-02-10', v_part_eq,  'ACT-2026-0004', NULL),
        (7, TRUE,  'Pedido SC-003: mobiliario de oficina (dato de fabrica)',             2500.00, DATE '2026-01-18', v_part_mob, NULL, 'C3'),
        (8, FALSE, 'Compra escritorio ejecutivo ACT-2026-0005 (dato de fabrica)',         950.00, DATE '2026-01-20', v_part_mob, 'ACT-2026-0005', 'C3'),
        (9, FALSE, 'Compra silla ergonomica ACT-2026-0006 (dato de fabrica)',             480.00, DATE '2026-01-20', v_part_mob, 'ACT-2026-0006', 'C3'),
        (10, FALSE,'Compra archivador metalico ACT-2026-0007 (dato de fabrica)',          620.00, DATE '2026-01-25', v_part_mob, 'ACT-2026-0007', 'C3'),
        (11, FALSE,'Mantenimiento de instalaciones electricas (dato de fabrica)',        1200.00, DATE '2026-03-12', v_part_inst, NULL, NULL);

    FOR e IN SELECT * FROM tmp_seed_ejecuciones ORDER BY ord LOOP
        IF EXISTS (SELECT 1 FROM ejecucion_presupuestaria WHERE concepto = e.concepto) THEN
            CONTINUE;
        END IF;

        -- La columna partida_id es NOT NULL: si la partida no existe todavia se
        -- omite esta fila. Antes esta comprobacion no existia y el error
        -- ("null value in column partida_id") hacia fallar TODO el script,
        -- dejando la base sin datos de Sprint 3.
        IF e.partida IS NULL THEN
            RAISE NOTICE 'Partida no disponible; se omite la ejecucion "%".', e.concepto;
            CONTINUE;
        END IF;

        IF e.es_compromiso THEN
            INSERT INTO ejecucion_presupuestaria
                (empresa_id, partida_id, fecha, concepto, monto, tipo, activo_id, compromiso_id, usuario_id)
            VALUES (1, e.partida, e.fecha, e.concepto, e.monto, 'COMPROMISO', NULL, NULL, v_financiero)
            RETURNING id INTO v_comp;
        ELSE
            INSERT INTO ejecucion_presupuestaria
                (empresa_id, partida_id, fecha, concepto, monto, tipo, activo_id, compromiso_id, usuario_id)
            SELECT 1, e.partida, e.fecha, e.concepto, e.monto, 'EJECUCION', a.id,
                   (SELECT id FROM ejecucion_presupuestaria
                     WHERE concepto LIKE 'Pedido ' || e.clave_compromiso || ':%' LIMIT 1),
                   v_financiero
              FROM activo a WHERE a.codigo = e.codigo_activo
             UNION ALL
            SELECT 1, e.partida, e.fecha, e.concepto, e.monto, 'EJECUCION', NULL, NULL, v_financiero
             WHERE e.codigo_activo IS NULL
            LIMIT 1;
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 6. Pagos de la suscripcion SaaS
-- Tres cuotas mensuales ya aprobadas y una pendiente, ligadas a la suscripcion
-- activa de la empresa demo (plan Empresarial, 1000 Bs/mes).
DO $$
DECLARE
    v_sus INT;
    p     RECORD;
BEGIN
    SELECT id INTO v_sus FROM suscripcion WHERE empresa_id = 1 ORDER BY id LIMIT 1;
    IF v_sus IS NULL THEN
        RETURN;
    END IF;

    FOR p IN
        SELECT * FROM (VALUES
            ('PAGO-2026-08-001', 1000.00, 'TRANSFERENCIA_BANCARIA', 'APROBADO',
             TIMESTAMP '2026-08-05 10:15:00', '{"banco":"Banco Union","moneda":"BOB","cuota":"agosto 2026"}'),
            ('PAGO-2026-09-001', 1000.00, 'TARJETA_CREDITO', 'APROBADO',
             TIMESTAMP '2026-09-05 10:20:00', '{"entidad":"Visa","ultimos4":"4821","cuota":"septiembre 2026"}'),
            ('PAGO-2026-10-001', 1000.00, 'TRANSFERENCIA_BANCARIA', 'APROBADO',
             TIMESTAMP '2026-10-05 09:05:00', '{"banco":"Banco Mercantil","moneda":"BOB","cuota":"octubre 2026"}'),
            ('PAGO-2026-11-001', 1000.00, 'EFECTIVO', 'PENDIENTE',
             TIMESTAMP '2026-11-05 09:00:00', '{"cuota":"noviembre 2026","observacion":"pendiente de conciliacion"}')
        ) AS t(referencia, monto, metodo, estado, fecha, detalle)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pago WHERE referencia = p.referencia) THEN
            INSERT INTO pago (suscripcion_id, monto, metodo, proveedor, referencia, estado, detalle, fecha)
            VALUES (v_sus, p.monto, p.metodo, p.metodo, p.referencia, p.estado, p.detalle::jsonb, p.fecha);
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 7. Verificaciones de inventario
-- Jornada de conteo fisico con GPS (coordenadas de Santa Cruz de la Sierra),
-- incluyendo un NO_ENCONTRADO (activo dado de baja) y una diferencia de estado.
DO $$
DECLARE
    v_encargado INT;
    v           RECORD;
BEGIN
    SELECT id INTO v_encargado FROM usuario WHERE correo = 'encargado@uagrm.edu.bo';

    FOR v IN
        SELECT * FROM (VALUES
            ('ACT-2026-0001', 'ENCONTRADO',       -17.78331, -63.18255,  8.0,  'Verificado en la oficina de sistemas, etiqueta legible.'),
            ('ACT-2026-0002', 'ENCONTRADO',       -17.78328, -63.18249,  9.5,  'Verificado en la oficina de sistemas, en el puesto de trabajo.'),
            ('ACT-2026-0003', 'ENCONTRADO',       -17.78402, -63.18310, 12.0,  'Verificado en el almacen central, embalaje en buen estado.'),
            ('ACT-2026-0004', 'DIFERENCIA_ESTADO',-17.78405, -63.18314, 11.0,  'El sistema figura DISPONIBLE pero el activo esta en mantenimiento.'),
            ('ACT-2026-0005', 'ENCONTRADO',       -17.78390, -63.18298,  7.5,  'Verificado en el area administrativa.'),
            ('ACT-2026-0009', 'NO_ENCONTRADO',    -17.78410, -63.18320, 14.0,  'No ubicado durante el conteo; corresponde a un activo dado de baja.')
        ) AS t(codigo, resultado, lat, lon, prec, observacion)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM verificacion_inventario vi
                       JOIN activo a ON a.id = vi.activo_id
                      WHERE a.codigo = v.codigo AND vi.observacion = v.observacion) THEN
            INSERT INTO verificacion_inventario
                (empresa_id, activo_id, usuario_id, fecha_hora, latitud, longitud,
                 precision_m, resultado, foto_url, observacion)
            SELECT 1, a.id, v_encargado, TIMESTAMP '2026-10-18 15:00:00',
                   v.lat, v.lon, v.prec, v.resultado, NULL, v.observacion
              FROM activo a WHERE a.codigo = v.codigo;
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 8. Consultas guardadas
-- Definiciones validas segun el catalogo whitelist del motor de consultas,
-- listas para ejecutarse desde la pantalla de consultas dinamicas.
DO $$
DECLARE
    v_admin INT;
    c       RECORD;
BEGIN
    SELECT id INTO v_admin FROM usuario WHERE correo = 'admin@uagrm.edu.bo';

    FOR c IN
        SELECT * FROM (VALUES
            ('Activos actualmente en uso', 'activo',
             '{"entidad":"activo","columnas":["codigo","nombre","estado","valor"],"filtros":[{"campo":"estado","operador":"=","valor":"EN_USO"}],"orden":[{"campo":"codigo","direccion":"ASC"}],"limite":100}'),
            ('Mantenimientos con su costo', 'mantenimiento',
             '{"entidad":"mantenimiento","columnas":["id","activo_id","tipo","estado","costo","tecnico"],"orden":[{"campo":"fecha_programada","direccion":"DESC"}],"limite":100}'),
            ('Total ejecutado por partida', 'ejecucion_presupuestaria',
             '{"entidad":"ejecucion_presupuestaria","columnas":["partida_id","monto"],"filtros":[{"campo":"tipo","operador":"=","valor":"EJECUCION"}],"agregacion":{"funcion":"SUM","campo":"monto","agruparPor":["partida_id"]},"limite":100}')
        ) AS t(nombre, entidad, definicion)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM consulta_guardada WHERE nombre = c.nombre AND empresa_id = 1) THEN
            INSERT INTO consulta_guardada (empresa_id, usuario_id, nombre, entidad, definicion, fecha)
            VALUES (1, v_admin, c.nombre, c.entidad, c.definicion::jsonb, TIMESTAMP '2026-10-10 12:00:00');
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 9. Respaldos ficticios
-- Historial de respaldos (local y nube) con tamano y huella SHA-256.
DO $$
DECLARE
    v_admin INT;
    v_tiene_crypto BOOLEAN;
    v_hash  VARCHAR(64);
    r       RECORD;
BEGIN
    SELECT id INTO v_admin FROM usuario WHERE correo = 'admin@uagrm.edu.bo';
    SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') INTO v_tiene_crypto;

    FOR r IN
        SELECT * FROM (VALUES
            ('respaldos/respaldo_programado_20261001_020000.sql',  'PROGRAMADO', 'LOCAL', 482130, TIMESTAMP '2026-10-01 02:00:00', NULL),
            ('respaldos/respaldo_manual_20261010_153000.sql',      'MANUAL',     'LOCAL', 512884, TIMESTAMP '2026-10-10 15:30:00', 1),
            ('respaldos/respaldo_seguridad_20261015_230000.sql',   'SEGURIDAD',  'LOCAL', 524288, TIMESTAMP '2026-10-15 23:00:00', 1),
            ('respaldos/respaldo_plataforma_20261020_020000.sql',  'PLATAFORMA', 'NUBE',  530122, TIMESTAMP '2026-10-20 02:00:00', NULL)
        ) AS t(archivo, tipo, destino, tamano, fecha, usuario_id)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM respaldo WHERE archivo = r.archivo) THEN
            IF v_tiene_crypto THEN
                v_hash := encode(digest(r.archivo || r.fecha::text, 'sha256'), 'hex');
            ELSE
                -- Sin pgcrypto se compone una huella de 64 caracteres hex con md5 nativo.
                v_hash := md5(r.archivo || r.fecha::text) || md5(r.archivo || r.fecha::text || 'demo');
            END IF;
            INSERT INTO respaldo (empresa_id, tipo, destino, archivo, tamano_bytes, sha256,
                                  estado, usuario_id, fecha)
            VALUES (1, r.tipo, r.destino, r.archivo, r.tamano, v_hash, 'COMPLETADO',
                    COALESCE(r.usuario_id, v_admin), r.fecha);
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------- 10. Programacion de respaldo
INSERT INTO programacion_respaldo (empresa_id, frecuencia, hora, copias_a_conservar, destino, activa)
SELECT 1, 'SEMANAL', '02:00', 3, 'LOCAL', TRUE
WHERE NOT EXISTS (SELECT 1 FROM programacion_respaldo WHERE empresa_id = 1);

-- ------------------------------------------------- 11. Bitacora de auditoria
-- Eventos de fabrica con la cadena de hashes SHA-256 correctamente encadenada
-- (mismo formato que AuditoriaService: empresa|usuario|accion|entidad|id|
-- detalle|ip|equipo|fechaISO|hashAnterior, nulos como cadena vacia). Si la
-- cadena ya tiene eventos de fabrica no se repite; si la aplicacion ya habia
-- registrado eventos, los nuevos se encadenan despues del ultimo hash.
DO $$
DECLARE
    v_tiene_crypto BOOLEAN;
    v_previo       VARCHAR(64);
    v_hash         VARCHAR(64);
    v_empresa      TEXT;
    v_admin        INT;
    v_encargado    INT;
    v_financiero   INT;
    e              RECORD;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') INTO v_tiene_crypto;
    IF NOT v_tiene_crypto THEN
        RAISE NOTICE 'Sin pgcrypto: se omite la siembra de la bitacora (se llenara con el uso real).';
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM bitacora_auditoria WHERE detalle LIKE '[demo] %') THEN
        RETURN;
    END IF;

    SELECT id INTO v_admin     FROM usuario WHERE correo = 'admin@uagrm.edu.bo';
    SELECT id INTO v_encargado FROM usuario WHERE correo = 'encargado@uagrm.edu.bo';
    SELECT id INTO v_financiero FROM usuario WHERE correo = 'financiero@uagrm.edu.bo';

    SELECT COALESCE(MAX(hash_registro), 'GENESIS') INTO v_previo FROM bitacora_auditoria;

    FOR e IN
        SELECT * FROM (VALUES
            (v_admin,      'LOGIN',       'AUTENTICACION',         NULL, '[demo] Inicio de sesion exitoso del administrador',           '192.168.1.10', 'PC-OFICINA-01',  TIMESTAMP '2026-10-01 08:00:00'),
            (v_encargado,  'CREAR',       'ACTIVO',                '1',  '[demo] Registro del activo ACT-2026-0001 Laptop Dell',        '192.168.1.22', 'PC-ALMACEN-02',  TIMESTAMP '2026-01-15 09:15:00'),
            (v_encargado,  'CREAR',       'ACTIVO',                '2',  '[demo] Registro del activo ACT-2026-0002 Laptop HP',          '192.168.1.22', 'PC-ALMACEN-02',  TIMESTAMP '2026-01-15 09:20:00'),
            (v_admin,      'ASIGNAR',     'ASIGNACION',            NULL, '[demo] Asignacion de activos a responsables de area',         '192.168.1.10', 'PC-OFICINA-01',  TIMESTAMP '2026-02-01 09:00:00'),
            (v_financiero, 'CREAR',       'PRESUPUESTO',           NULL, '[demo] Registro del presupuesto de la gestion 2026',          '192.168.1.30', 'PC-FINANZAS-01', TIMESTAMP '2026-01-05 10:00:00'),
            (v_financiero, 'EJECUTAR',    'PARTIDA_PRESUPUESTARIA',NULL, '[demo] Registro de compromisos y ejecuciones presupuestarias','192.168.1.30', 'PC-FINANZAS-01', TIMESTAMP '2026-01-15 11:30:00'),
            (v_encargado,  'PROGRAMAR',   'MANTENIMIENTO',         NULL, '[demo] Programacion de mantenimientos preventivos y correctivos','192.168.1.22','PC-ALMACEN-02', TIMESTAMP '2026-04-01 08:30:00'),
            (v_encargado,  'VERIFICAR',   'INVENTARIO',            NULL, '[demo] Jornada de verificacion fisica de inventario con GPS', '192.168.1.22', 'MOVIL-ALMACEN',  TIMESTAMP '2026-10-18 15:00:00'),
            (v_admin,      'GENERAR',     'RESPALDO',              NULL, '[demo] Generacion de respaldo manual de la base de datos',    '192.168.1.10', 'PC-OFICINA-01',  TIMESTAMP '2026-10-10 15:30:00'),
            (v_admin,      'PERSONALIZAR','CONFIG_EMPRESA',        NULL, '[demo] Personalizacion de colores corporativos de la empresa', '192.168.1.10','PC-OFICINA-01',  TIMESTAMP '2026-10-12 17:45:00')
        ) AS t(usuario_id, accion, entidad, entidad_id, detalle, ip, equipo, fecha)
    LOOP
        v_empresa := '1';
        v_hash := encode(digest(
            concat_ws('|',
                v_empresa,
                (SELECT correo FROM usuario WHERE id = e.usuario_id),
                e.accion, e.entidad,
                COALESCE(e.entidad_id, ''), COALESCE(e.detalle, ''),
                COALESCE(e.ip, ''), COALESCE(e.equipo, ''),
                -- ISO_LOCAL_DATE_TIME de Java omite la fraccion cuando es cero;
                -- todas las fechas de fabrica tienen nanosegundos en cero.
                to_char(e.fecha, 'YYYY-MM-DD"T"HH24:MI:SS'),
                v_previo),
            'sha256'), 'hex');

        INSERT INTO bitacora_auditoria
            (empresa_id, usuario_id, usuario_nombre, accion, entidad, entidad_id,
             detalle, ip, equipo, fecha_hora, hash_anterior, hash_registro)
        SELECT 1, e.usuario_id, u.correo, e.accion, e.entidad, e.entidad_id,
               e.detalle, e.ip, e.equipo, e.fecha, v_previo, v_hash
          FROM usuario u WHERE u.id = e.usuario_id;

        v_previo := v_hash;
    END LOOP;
END $$;
