import { Injectable } from '@angular/core';
import { Pipe, PipeTransform } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

export type Idioma = 'es' | 'en';

/**
 * HU-15: internacionalizacion es/en sin librerias externas.
 * El idioma lo define la personalizacion de la empresa; el usuario puede
 * cambiarlo en sesion y queda guardado en localStorage.
 */
@Injectable({ providedIn: 'root' })
export class IdiomaService {
  private readonly CLAVE = 'idioma';
  private idioma$ = new BehaviorSubject<Idioma>((localStorage.getItem(this.CLAVE) as Idioma) || 'es');
  idiomaActual = this.idioma$.asObservable();

  private readonly DICCIONARIO: Record<Idioma, Record<string, string>> = {
    es: {
      'menu.activos': 'Activos',
      'menu.mantenimientos': 'Mantenimientos',
      'menu.depreciacion': 'Depreciación',
      'menu.presupuestos': 'Presupuestos',
      'menu.usuarios': 'Usuarios',
      'menu.roles': 'Roles y permisos',
      'menu.reportes': 'Reportes',
      'menu.bi': 'Tablero BI',
      'menu.ia': 'Asistente IA',
      'menu.respaldos': 'Respaldos',
      'menu.auditoria': 'Auditoría',
      'menu.inventario': 'Inventario',
      'menu.suscripcion': 'Suscripción',
      'menu.configuracion': 'Personalización',
      'menu.plataforma': 'Administración de plataforma',
      'comun.guardar': 'Guardar',
      'comun.cancelar': 'Cancelar',
      'comun.eliminar': 'Eliminar',
      'comun.descargar': 'Descargar',
      'comun.buscar': 'Buscar',
      'comun.cargando': 'Cargando...',
      'comun.error': 'Ocurrió un error',
      'comun.si': 'Sí',
      'comun.no': 'No',
      'comun.estado': 'Estado',
      'comun.acciones': 'Acciones',
      'comun.fecha': 'Fecha',
      'comun.nombre': 'Nombre',
      'comun.salir': 'Cerrar sesión',
      'comun.sinDatos': 'No hay datos para mostrar',
      'comun.confirmar': '¿Está seguro? Esta acción no se puede deshacer.',
      'login.registro': '¿No tienes cuenta? Registra tu empresa',
      'registro.titulo': 'Registro de empresa',
      'registro.subtitulo': 'Crea el espacio de trabajo de tu organización en minutos',
      'suscripcion.plan': 'Plan actual',
      'suscripcion.contratar': 'Contratar / renovar',
      'ia.pregunta': 'Pregunta en lenguaje natural...',
      'ia.enviar': 'Preguntar',
      'ia.modoGuiado': 'Modo guiado (sin IA externa)',
      'reporte.exportarPdf': 'Exportar PDF',
      'reporte.exportarExcel': 'Exportar Excel',
      'reporte.ejecutar': 'Ejecutar consulta',
      'respaldo.crear': 'Crear respaldo ahora',
      'respaldo.restaurar': 'Restaurar',
      'auditoria.verificar': 'Verificar integridad de la cadena',
      'inventario.verificar': 'Registrar verificación'
    },
    en: {
      'menu.activos': 'Assets',
      'menu.mantenimientos': 'Maintenance',
      'menu.depreciacion': 'Depreciation',
      'menu.presupuestos': 'Budgets',
      'menu.usuarios': 'Users',
      'menu.roles': 'Roles and permissions',
      'menu.reportes': 'Reports',
      'menu.bi': 'BI dashboard',
      'menu.ia': 'AI assistant',
      'menu.respaldos': 'Backups',
      'menu.auditoria': 'Audit log',
      'menu.inventario': 'Inventory',
      'menu.suscripcion': 'Subscription',
      'menu.configuracion': 'Customization',
      'menu.plataforma': 'Platform administration',
      'comun.guardar': 'Save',
      'comun.cancelar': 'Cancel',
      'comun.eliminar': 'Delete',
      'comun.descargar': 'Download',
      'comun.buscar': 'Search',
      'comun.cargando': 'Loading...',
      'comun.error': 'An error occurred',
      'comun.si': 'Yes',
      'comun.no': 'No',
      'comun.estado': 'Status',
      'comun.acciones': 'Actions',
      'comun.fecha': 'Date',
      'comun.nombre': 'Name',
      'comun.salir': 'Log out',
      'comun.sinDatos': 'No data to display',
      'comun.confirmar': 'Are you sure? This action cannot be undone.',
      'login.registro': "Don't have an account? Register your company",
      'registro.titulo': 'Company registration',
      'registro.subtitulo': 'Create your organization workspace in minutes',
      'suscripcion.plan': 'Current plan',
      'suscripcion.contratar': 'Subscribe / renew',
      'ia.pregunta': 'Ask in natural language...',
      'ia.enviar': 'Ask',
      'ia.modoGuiado': 'Guided mode (no external AI)',
      'reporte.exportarPdf': 'Export PDF',
      'reporte.exportarExcel': 'Export Excel',
      'reporte.ejecutar': 'Run query',
      'respaldo.crear': 'Create backup now',
      'respaldo.restaurar': 'Restore',
      'auditoria.verificar': 'Verify hash chain integrity',
      'inventario.verificar': 'Register verification'
    }
  };

  cambiar(idioma: Idioma): void {
    localStorage.setItem(this.CLAVE, idioma);
    this.idioma$.next(idioma);
  }

  obtener(): Idioma {
    return this.idioma$.value;
  }

  traducir(clave: string): string {
    return this.DICCIONARIO[this.idioma$.value][clave]
      ?? this.DICCIONARIO.es[clave]
      ?? clave;
  }
}

/** Uso en plantillas: {{ 'menu.activos' | t }} */
@Pipe({ name: 't', standalone: true, pure: false })
export class TraduccionPipe implements PipeTransform {
  constructor(private idioma: IdiomaService) {}

  transform(clave: string): string {
    return this.idioma.traducir(clave);
  }
}
