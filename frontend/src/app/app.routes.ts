import { Routes } from '@angular/router';
import { LoginComponent } from './features/login/login.component';
import { ActivosComponent } from './features/activos/activos.component';
import { ActivoDetalleComponent } from './features/activos/activo-detalle.component';
import { MantenimientosComponent } from './features/mantenimientos/mantenimientos.component';
import { DepreciacionComponent } from './features/depreciacion/depreciacion.component';
import { PresupuestosComponent } from './features/presupuestos/presupuestos.component';
import { PresupuestoDetalleComponent } from './features/presupuestos/presupuesto-detalle.component';
import { adminGuard, permissionGuard, superAdminGuard } from './core/auth/auth.guard';

import { UsuariosComponent } from './components/usuarios/usuarios.component';
import { RolesComponent } from './features/roles/roles.component';

// Sprint 3 (HU-11…HU-17)
import { RegistroEmpresaComponent } from './features/registro/registro-empresa.component';
import { EmpresasPlataformaComponent } from './features/plataforma/empresas.component';
import { SuscripcionComponent } from './features/suscripcion/suscripcion.component';
import { ReportesComponent } from './features/reportes/reportes.component';
import { BiComponent } from './features/reportes/bi.component';
import { IaComponent } from './features/ia/ia.component';
import { PersonalizacionComponent } from './features/configuracion/personalizacion.component';
import { RespaldosComponent } from './features/respaldos/respaldos.component';
import { BitacoraComponent } from './features/auditoria/bitacora.component';
import { InventarioComponent } from './features/inventario/inventario.component';

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  // HU-11: registro publico, sin autenticacion
  { path: 'registro-empresa', component: RegistroEmpresaComponent },

  // HU-12: Super Admin de la plataforma
  { path: 'plataforma/empresas', component: EmpresasPlataformaComponent, canActivate: [superAdminGuard] },

  { path: 'activos', component: ActivosComponent, canActivate: [permissionGuard], data: { permission: 'ACTIVOS_LEER' } },
  { path: 'activos/:id', component: ActivoDetalleComponent, canActivate: [permissionGuard], data: { permission: 'ACTIVOS_LEER' } },
  { path: 'mantenimientos', component: MantenimientosComponent, canActivate: [permissionGuard], data: { permission: 'MANTENIMIENTO_LEER' } },
  { path: 'depreciacion', component: DepreciacionComponent, canActivate: [permissionGuard], data: { permission: 'DEPRECIACION_LEER' } },
  { path: 'presupuestos', component: PresupuestosComponent, canActivate: [permissionGuard], data: { permission: 'PRESUPUESTO_LEER' } },
  { path: 'presupuestos/:id', component: PresupuestoDetalleComponent, canActivate: [permissionGuard], data: { permission: 'PRESUPUESTO_LEER' } },
  { path: 'usuarios', component: UsuariosComponent, canActivate: [permissionGuard], data: { permission: 'USUARIOS_LEER' } },
  { path: 'roles', component: RolesComponent, canActivate: [adminGuard] },

  // HU-13/HU-14: reportes, BI, IA y auditoria
  { path: 'reportes', component: ReportesComponent, canActivate: [permissionGuard], data: { permission: 'REPORTES_LEER' } },
  { path: 'bi', component: BiComponent, canActivate: [permissionGuard], data: { permission: 'REPORTES_LEER' } },
  { path: 'ia', component: IaComponent, canActivate: [permissionGuard], data: { permission: 'IA_CONSULTAR' } },
  { path: 'auditoria', component: BitacoraComponent, canActivate: [permissionGuard], data: { permission: 'AUDITORIA_LEER' } },

  // HU-15/HU-16/HU-17
  { path: 'suscripcion', component: SuscripcionComponent, canActivate: [permissionGuard], data: { permission: 'SUSCRIPCION_LEER' } },
  { path: 'respaldos', component: RespaldosComponent, canActivate: [permissionGuard], data: { permission: 'RESPALDO_GESTIONAR' } },
  { path: 'configuracion', component: PersonalizacionComponent, canActivate: [permissionGuard], data: { permission: 'CONFIG_EMPRESA_EDITAR' } },
  { path: 'inventario', component: InventarioComponent, canActivate: [permissionGuard], data: { permission: 'INVENTARIO_LEER' } },

  { path: '**', redirectTo: 'login' }
];
