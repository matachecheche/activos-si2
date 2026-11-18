-- ============================================================================
-- Sprint 3 / MULTIEMPRESA: segunda empresa de demostracion + cuentas globales
-- ----------------------------------------------------------------------------
-- Idempotente: se puede correr varias veces sin duplicar nada.
--
-- Que resuelve:
--   1. La identidad de la persona vive en `cuenta` (correo unico global) y las
--      membresias por empresa en `usuario` (unico por empresa_id + correo).
--   2. La empresa 2 ("Sede Norte") existe con sus roles, permisos, configuracion
--      y suscripcion, para demostrar el aislamiento entre empresas.
--   3. El administrador de la empresa 1 tambien es administrador de la empresa 2:
--      con un solo login puede cambiar de empresa desde la web y desde el movil.
--   4. Datos minimos (categorias, ubicaciones, areas, activos) para que la
--      empresa 2 no muestre pantallas vacias.
-- ============================================================================

-- ------------------------------------------------------------------ 1. Empresa 2
INSERT INTO empresa (id, nombre, nit, rubro, correo_contacto, estado, fecha_registro)
SELECT 2, 'Empresa Demo UAGRM - Sede Norte', '2000002000', 'Educacion superior',
       'admin@uagrm.edu.bo', 'ACTIVA', now()
WHERE NOT EXISTS (SELECT 1 FROM empresa WHERE id = 2);
SELECT setval(pg_get_serial_sequence('empresa', 'id'), GREATEST((SELECT MAX(id) FROM empresa), 1));

-- ------------------------------------------------------------------ 2. Roles propios
INSERT INTO rol (empresa_id, nombre, descripcion, es_sistema, activo)
SELECT 2, r.nombre, r.descripcion, r.es_sistema, COALESCE(r.activo, true)
FROM rol r
WHERE r.empresa_id = 1
  AND NOT EXISTS (SELECT 1 FROM rol r2 WHERE r2.empresa_id = 2 AND r2.nombre = r.nombre);

-- Permisos de cada rol (copia de los de la empresa 1)
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r2.id, rp.permiso_id
FROM rol r1
JOIN rol_permiso rp ON rp.rol_id = r1.id
JOIN rol r2 ON r2.empresa_id = 2 AND r2.nombre = r1.nombre
WHERE r1.empresa_id = 1
  AND NOT EXISTS (
      SELECT 1 FROM rol_permiso x WHERE x.rol_id = r2.id AND x.permiso_id = rp.permiso_id);

-- ------------------------------------------------------------------ 3. Configuracion y suscripcion
INSERT INTO configuracion_empresa (empresa_id, color_primario, color_secundario, idioma, menu_config)
SELECT 2, '#0f766e', '#134e4a', 'es', '[]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM configuracion_empresa WHERE empresa_id = 2);

INSERT INTO suscripcion (empresa_id, plan_id, fecha_inicio, fecha_vencimiento, estado, fecha_estado)
SELECT 2, p.id, now(), now() + INTERVAL '12 months', 'ACTIVA', now()
FROM plan p
WHERE p.nombre = 'Profesional'
  AND NOT EXISTS (SELECT 1 FROM suscripcion s WHERE s.empresa_id = 2);

-- ------------------------------------------------------------------ 4. Cuentas globales
-- Una cuenta por persona (correo unico global). Se toma la membresia mas antigua
-- como referencia para el nombre, el hash de contrasena y el estado.
INSERT INTO cuenta (correo, nombre, password, nivel, intentos_fallidos, bloqueado_hasta, activo)
SELECT DISTINCT ON (u.correo)
       u.correo, u.nombre, u.password,
       CASE WHEN u.nivel IN ('SUPER_ADMIN', 'ADMIN', 'REGULAR') THEN u.nivel ELSE 'REGULAR' END,
       COALESCE(u.intentos_fallidos, 0), u.bloqueado_hasta, COALESCE(u.activo, true)
FROM usuario u
WHERE u.correo IS NOT NULL AND u.correo <> ''
ORDER BY u.correo, u.empresa_id NULLS LAST, u.id
ON CONFLICT (correo) DO NOTHING;

-- Enlaza cada membresia con su cuenta global
UPDATE usuario u
SET cuenta_id = c.id
FROM cuenta c
WHERE c.correo = u.correo AND u.cuenta_id IS NULL;

-- ------------------------------------------------------------------ 5. Membresia cruzada
-- El administrador de la empresa 1 tambien administra la empresa 2 (mismo login).
INSERT INTO usuario (empresa_id, nombre, correo, password, rol_id, cuenta_id, nivel,
                     intentos_fallidos, bloqueado_hasta, activo)
SELECT 2, 'Administrador (prueba)', 'admin@uagrm.edu.bo', c.password, r.id, c.id, 'ADMIN',
       0, NULL, true
FROM rol r
CROSS JOIN cuenta c
WHERE r.empresa_id = 2 AND r.nombre = 'ADMINISTRADOR'
  AND c.correo = 'admin@uagrm.edu.bo'
  AND NOT EXISTS (
      SELECT 1 FROM usuario u WHERE u.empresa_id = 2 AND u.correo = 'admin@uagrm.edu.bo');

-- Usuario propio de la sede norte (persona distinta: solo existe en la empresa 2)
INSERT INTO cuenta (correo, nombre, password, nivel, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'norte@uagrm.edu.bo', 'Responsable Sede Norte',
       '$2a$10$uKwL2ZI3eM6xjZLugF89RejQXttfuj56bUmywSn299kHvqF2ZEFFG',
       'REGULAR', 0, NULL, true
WHERE NOT EXISTS (SELECT 1 FROM cuenta c WHERE c.correo = 'norte@uagrm.edu.bo');

INSERT INTO usuario (empresa_id, nombre, correo, password, rol_id, cuenta_id, nivel,
                     intentos_fallidos, bloqueado_hasta, activo)
SELECT 2, 'Responsable Sede Norte', 'norte@uagrm.edu.bo', c.password, r.id, c.id, 'REGULAR',
       0, NULL, true
FROM rol r
CROSS JOIN cuenta c
WHERE r.empresa_id = 2 AND r.nombre = 'ENCARGADO_ACTIVOS'
  AND c.correo = 'norte@uagrm.edu.bo'
  AND NOT EXISTS (
      SELECT 1 FROM usuario u WHERE u.empresa_id = 2 AND u.correo = 'norte@uagrm.edu.bo');

-- ------------------------------------------------------------------ 6. Datos minimos de la sede norte
INSERT INTO categoria (empresa_id, nombre)
SELECT 2, v.nombre
FROM (VALUES ('Equipos informaticos'), ('Mobiliario'), ('Vehiculos')) AS v(nombre)
WHERE NOT EXISTS (SELECT 1 FROM categoria c WHERE c.empresa_id = 2 AND c.nombre = v.nombre);

-- Los parametros de depreciacion se copian de la empresa 1: sin ellos los
-- activos de la sede norte no se depreciarian y sus pantallas saldrian vacias.
UPDATE categoria c2
SET depreciable = c1.depreciable,
    metodo_depreciacion = c1.metodo_depreciacion,
    valor_residual_pct = c1.valor_residual_pct,
    vida_util = c1.vida_util
FROM categoria c1
WHERE c1.empresa_id = 1 AND c2.empresa_id = 2 AND c1.nombre = c2.nombre
  AND (c2.depreciable IS NULL OR c2.vida_util IS NULL);

INSERT INTO ubicacion (empresa_id, nombre)
SELECT 2, v.nombre
FROM (VALUES ('Almacen sede norte'), ('Oficina de direccion norte')) AS v(nombre)
WHERE NOT EXISTS (SELECT 1 FROM ubicacion u WHERE u.empresa_id = 2 AND u.nombre = v.nombre);

INSERT INTO area (empresa_id, nombre, descripcion, activo)
SELECT 2, v.nombre, v.descripcion, true
FROM (VALUES ('Direccion Sede Norte', 'Gestion administrativa de la sede norte'),
             ('Sistemas Sede Norte', 'Soporte tecnologico de la sede norte')) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM area a WHERE a.empresa_id = 2 AND a.nombre = v.nombre);

INSERT INTO activo (empresa_id, codigo, nombre, categoria_id, valor, fecha_adquisicion,
                     proveedor, estado)
SELECT 2, v.codigo, v.nombre, c.id, v.valor, v.fecha, v.proveedor, 'SIN_ASIGNAR'
FROM (VALUES
        ('NTE-2026-0001', 'Laptop Lenovo ThinkPad E14', 7200.00, DATE '2026-01-18', 'Tecnodata SRL'),
        ('NTE-2026-0002', 'Desktop HP ProDesk 400 G9', 5600.00, DATE '2026-02-03', 'Tecnodata SRL'),
        ('NTE-2026-0003', 'Silla de oficina ergonomica', 520.00, DATE '2026-02-10', 'Muebleria San Martin'),
        ('NTE-2026-0004', 'Motocicleta Honda CB150', 13500.00, DATE '2026-03-12', 'Motos del Oriente')
     ) AS v(codigo, nombre, valor, fecha, proveedor)
JOIN categoria c ON c.empresa_id = 2 AND c.nombre = 'Equipos informaticos'
WHERE v.codigo IN ('NTE-2026-0001', 'NTE-2026-0002')
  AND NOT EXISTS (SELECT 1 FROM activo a WHERE a.empresa_id = 2 AND a.codigo = v.codigo)
UNION ALL
SELECT 2, v.codigo, v.nombre, c.id, v.valor, v.fecha, v.proveedor, 'SIN_ASIGNAR'
FROM (VALUES
        ('NTE-2026-0003', 'Silla de oficina ergonomica', 520.00, DATE '2026-02-10', 'Muebleria San Martin'),
        ('NTE-2026-0004', 'Motocicleta Honda CB150', 13500.00, DATE '2026-03-12', 'Motos del Oriente')
     ) AS v(codigo, nombre, valor, fecha, proveedor)
JOIN categoria c ON c.empresa_id = 2 AND c.nombre = 'Mobiliario'
WHERE v.codigo = 'NTE-2026-0003'
  AND NOT EXISTS (SELECT 1 FROM activo a WHERE a.empresa_id = 2 AND a.codigo = v.codigo)
UNION ALL
SELECT 2, v.codigo, v.nombre, c.id, v.valor, v.fecha, v.proveedor, 'SIN_ASIGNAR'
FROM (VALUES
        ('NTE-2026-0004', 'Motocicleta Honda CB150', 13500.00, DATE '2026-03-12', 'Motos del Oriente')
     ) AS v(codigo, nombre, valor, fecha, proveedor)
JOIN categoria c ON c.empresa_id = 2 AND c.nombre = 'Vehiculos'
WHERE NOT EXISTS (SELECT 1 FROM activo a WHERE a.empresa_id = 2 AND a.codigo = v.codigo);
