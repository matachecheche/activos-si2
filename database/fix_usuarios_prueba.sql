-- Usuarios de prueba (uno por rol). Si el correo ya existe, se actualiza
-- la contrasena y se desbloquea la cuenta (intentos_fallidos = 0).
INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Administrador (prueba)', 'admin@uagrm.edu.bo',
       '$2b$10$Vn.kCG30k/5rvSbwY9jPI.ZXSMnmtzZSAH.Lrxb7cFHzUfNyEcScy',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'ADMINISTRADOR'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;

INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Encargado de Activos (prueba)', 'encargado@uagrm.edu.bo',
       '$2b$10$Hmr7ACmODagliVeslQB82eOX.Cfq7gpaxuJ2N9pH5SA2WdoVwnmSC',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'ENCARGADO_ACTIVOS'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;

INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Contador (prueba)', 'contador@uagrm.edu.bo',
       '$2b$10$R4KjaSKjvE6j7l/bAwOmLOWzf7P3J6/qZy8GFhDlw3doLlVijztOi',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'CONTADOR'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;

INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Responsable Financiero (prueba)', 'financiero@uagrm.edu.bo',
       '$2b$10$R4DyovKsPU52RcaD4o6eAuVSQ9ZPJh.363GlQDLw8d/U4zp17Dgvu',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'RESPONSABLE_FINANCIERO'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;