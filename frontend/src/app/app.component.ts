import { Component, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterLink, Router } from '@angular/router';
import { AuthService } from './core/auth/auth.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent {
  constructor(public authService: AuthService, private router: Router) {}

  cerrarSesion(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  @HostListener('window:click') onActivity(): void { this.authService.registrarActividad(); }
  @HostListener('window:keydown') onKeyActivity(): void { this.authService.registrarActividad(); }
}
