export interface ItemMenu {
  etiqueta: string;
  ruta: string;
  permiso?: string;        // permiso MODULO_ACCION requerido
  soloAdmin?: boolean;     // administrador de la empresa
  soloSuperAdmin?: boolean; // HU-12: Super Admin de la plataforma
  claveI18n?: string;      // clave de traduccion es/en
}

/**
 * HU-01/HU-04/HU-11…HU-17: el menu se arma segun el nivel (SUPER_ADMIN,
 * ADMIN, REGULAR), el rol y los permisos contenidos en el JWT.
 */
export const MENU: ItemMenu[] = [
  { etiqueta: 'Administración de plataforma', ruta: '/plataforma/empresas', soloSuperAdmin: true, claveI18n: 'menu.plataforma' },
  { etiqueta: 'Activos', ruta: '/activos', permiso: 'ACTIVOS_LEER', claveI18n: 'menu.activos' },
  { etiqueta: 'Mantenimientos', ruta: '/mantenimientos', permiso: 'MANTENIMIENTO_LEER', claveI18n: 'menu.mantenimientos' },
  { etiqueta: 'Depreciación', ruta: '/depreciacion', permiso: 'DEPRECIACION_LEER', claveI18n: 'menu.depreciacion' },
  { etiqueta: 'Presupuestos', ruta: '/presupuestos', permiso: 'PRESUPUESTO_LEER', claveI18n: 'menu.presupuestos' },
  { etiqueta: 'Inventario', ruta: '/inventario', permiso: 'INVENTARIO_LEER', claveI18n: 'menu.inventario' },
  { etiqueta: 'Reportes', ruta: '/reportes', permiso: 'REPORTES_LEER', claveI18n: 'menu.reportes' },
  { etiqueta: 'Tablero BI', ruta: '/bi', permiso: 'REPORTES_LEER', claveI18n: 'menu.bi' },
  { etiqueta: 'Asistente IA', ruta: '/ia', permiso: 'IA_CONSULTAR', claveI18n: 'menu.ia' },
  { etiqueta: 'Usuarios', ruta: '/usuarios', permiso: 'USUARIOS_LEER', claveI18n: 'menu.usuarios' },
  { etiqueta: 'Roles y permisos', ruta: '/roles', soloAdmin: true, claveI18n: 'menu.roles' },
  { etiqueta: 'Suscripción', ruta: '/suscripcion', permiso: 'SUSCRIPCION_LEER', claveI18n: 'menu.suscripcion' },
  { etiqueta: 'Respaldos', ruta: '/respaldos', permiso: 'RESPALDO_GESTIONAR', claveI18n: 'menu.respaldos' },
  { etiqueta: 'Auditoría', ruta: '/auditoria', permiso: 'AUDITORIA_LEER', claveI18n: 'menu.auditoria' },
  { etiqueta: 'Personalización', ruta: '/configuracion', permiso: 'CONFIG_EMPRESA_EDITAR', claveI18n: 'menu.configuracion' }
];
