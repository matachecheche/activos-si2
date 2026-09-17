import { Routes } from '@angular/router';
import { LoginComponent } from './features/login/login.component';
import { ActivosComponent } from './features/activos/activos.component';
import { authGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'activos', component: ActivosComponent, canActivate: [authGuard] },
  { path: '**', redirectTo: 'login' }
];
