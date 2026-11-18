-- Usuarios de prueba (uno por rol). Si el correo ya existe en esa empresa, se
-- actualiza la contrasena y se desbloquea la cuenta (intentos_fallidos = 0).
--
-- Sprint 3 / multiempresa: el correo ya no es unico global, la unicidad real es
-- (empresa_id, correo). Por eso el script comprueba si la columna empresa_id ya
-- existe (migracion V3 aplicada) y, si existe,Vincula el usuario a la cuenta
-- global; si todavia no existe, se comporta como el script original del Sprint 1.

DO $$
DECLARE
    v_tiene_empresa BOOLEAN;
    v_hash_admin    CONSTANT TEXT := '$2b$10$Vn.kCG30k/5rvSbwY9jPI.ZXSMnmtzZSAH.Lrxb7cFHzUfNyEcScy';
    v_hash_encarg   CONSTANT TEXT := '$2b$10$Hmr7ACmODagliVeslQB82eOX.Cfq7gpaxuJ2N9pH5SA2WdoVwnmSC';
    v_hash_contador CONSTANT TEXT := '$2b$10$R4KjaSKjvE6j7l/bAwOmLOWzf7P3J6/qZy8GFhDlw3doLlVijztOi';
    v_hash_financ   CONSTANT TEXT := '$2b$10$R4DyovKsPU52RcaD4o6eAuVSQ9ZPJh.363GlQDLw8d/U4zp17Dgvu';
    r record;
BEGIN
    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'usuario' AND column_name = 'empresa_id')
        INTO v_tiene_empresa;

    FOR r IN SELECT * FROM (VALUES
            ('Administrador (prueba)', 'admin@uagrm.edu.bo', 'ADMINISTRADOR', v_hash_admin),
            ('Encargado de Activos (prueba)', 'encargado@uagrm.edu.bo', 'ENCARGADO_ACTIVOS', v_hash_encarg),
            ('Contador (prueba)', 'contador@uagrm.edu.bo', 'CONTADOR', v_hash_contador),
            ('Responsable Financiero (prueba)', 'financiero@uagrm.edu.bo', 'RESPONSABLE_FINANCIERO', v_hash_financ)
         ) AS t(nombre, correo, rol_nombre, hash) LOOP

        IF NOT v_tiene_empresa THEN
            -- Todavia no existe la columna empresa_id (Sprint 1): insercion simple.
            INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
            SELECT r.nombre, r.correo, r.hash, ro.id, 0, NULL, true
            FROM rol ro WHERE ro.nombre = r.rol_nombre
            ON CONFLICT (correo) DO UPDATE SET
                password = EXCLUDED.password,
                intentos_fallidos = 0,
                bloqueado_hasta = NULL,
                activo = true;
        ELSE
            -- Con multiempresa: una membresia por empresa (empresa 1 = demo).
            INSERT INTO usuario (empresa_id, nombre, correo, password, rol_id, nivel,
                                 intentos_fallidos, bloqueado_hasta, activo)
            SELECT 1, r.nombre, r.correo, r.hash, ro.id,
                   CASE WHEN r.rol_nombre = 'ADMINISTRADOR' THEN 'ADMIN' ELSE 'REGULAR' END,
                   0, NULL, true
            FROM rol ro
            WHERE ro.empresa_id = 1 AND ro.nombre = r.rol_nombre
              AND NOT EXISTS (SELECT 1 FROM usuario u
                              WHERE u.empresa_id = 1 AND u.correo = r.correo);

            UPDATE usuario u
            SET password = r.hash, intentos_fallidos = 0, bloqueado_hasta = NULL, activo = true
            FROM rol ro
            WHERE u.empresa_id = 1 AND u.correo = r.correo
              AND u.rol_id = ro.id AND ro.empresa_id = 1 AND ro.nombre = r.rol_nombre;
        END IF;
    END LOOP;
END $$;
