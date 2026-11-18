import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isLoggedIn() ? true : router.parseUrl('/login');
};

export const adminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (auth.isLoggedIn() && auth.isAdmin()) return true;
  return router.parseUrl(auth.rutaInicial());
};

/** HU-12: solo el Super Admin de la plataforma (no los administradores de empresa). */
export const superAdminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (auth.isLoggedIn() && auth.isSuperAdmin()) return true;
  return router.parseUrl(auth.rutaInicial());
};

/** HU-04: cada ruta declara en data.permission el permiso MODULO_ACCION que exige. */
export const permissionGuard: CanActivateFn = (route) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const permission = route.data['permission'] as string;
  if (auth.isLoggedIn() && auth.hasPermission(permission)) return true;
  return router.parseUrl(auth.rutaInicial());
};
