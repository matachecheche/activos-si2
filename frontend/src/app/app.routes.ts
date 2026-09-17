import { Routes } from '@angular/router';
import { LoginComponent } from './features/login/login.component';
import { ActivosComponent } from './features/activos/activos.component';
import { adminGuard, authGuard, permissionGuard } from './core/auth/auth.guard';

import { UsuariosComponent } from './components/usuarios/usuarios.component';
import { RolesComponent } from './features/roles/roles.component';

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'activos', component: ActivosComponent, canActivate: [permissionGuard], data: { permission: 'ACTIVOS_LEER' } },
  { path: 'usuarios', component: UsuariosComponent, canActivate: [permissionGuard], data: { permission: 'USUARIOS_LEER' } },
  { path: 'roles', component: RolesComponent, canActivate: [adminGuard] },
  { path: '**', redirectTo: 'login' }


];
