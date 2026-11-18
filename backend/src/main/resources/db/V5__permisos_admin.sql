-- =====================================================================================
-- Sprint 3 - Migracion V5 - el ADMINISTRADOR de cada empresa tiene acceso total
-- -------------------------------------------------------------------------------------
-- Motivo: si el rol ADMINISTRADOR se crea antes de que existan todos los permisos
-- (por ejemplo, cuando la base recien creada todavia no tiene el catalogo completo),
-- se queda sin ACTIVOS_*, PRESUPUESTO_*, REPORTES_LEER o USUARIOS_*. El menu de la
-- web y del movil se arma con los permisos del rol, asi que esos modulos desaparecian.
-- Esta migracion es idempotente: se puede ejecutar varias veces.
-- =====================================================================================

INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id
FROM rol r
CROSS JOIN permiso p
WHERE r.nombre = 'ADMINISTRADOR'
  AND NOT EXISTS (
      SELECT 1 FROM rol_permiso x
      WHERE x.rol_id = r.id AND x.permiso_id = p.id);

-- El rol SUPER_ADMIN de la plataforma tambien es de acceso total.
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id
FROM rol r
CROSS JOIN permiso p
WHERE r.nombre = 'SUPER_ADMIN'
  AND NOT EXISTS (
      SELECT 1 FROM rol_permiso x
      WHERE x.rol_id = r.id AND x.permiso_id = p.id);
