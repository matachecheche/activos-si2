import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { SaasService } from './saas.service';
import { Plan } from '../../core/models/sprint3.models';
import { AuthService } from '../../core/auth/auth.service';

interface RegistroForm {
  nombreEmpresa: string;
  nit: string;
  rubro: string;
  correoContacto: string;
  planId: number | null;
  nombreAdmin: string;
  correoAdmin: string;
  passwordAdmin: string;
  metodoPago: 'MERCADO_PAGO' | 'PAYPAL' | 'TRANSFERENCIA';
  meses: number;
}

@Component({
  selector: 'app-registro-empresa',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './registro-empresa.component.html',
  styleUrl: './registro-empresa.component.scss'
})
export class RegistroEmpresaComponent implements OnInit {
  planes: Plan[] = [];
  enviando = false;
  errorMsg = '';
  exito: any = null;
  /** Sprint 3 / multiempresa: si el usuario ya tiene sesion, la empresa nueva
   *  se agrega a su cuenta (no pide contrasena ni correo). */
  sesionActiva = false;
  correoSesion = '';
  /** Id de la empresa recien agregada (para cambiar a ella). */
  empresaNuevaId?: number;

  form: RegistroForm = {
    nombreEmpresa: '',
    nit: '',
    rubro: '',
    correoContacto: '',
    planId: null,
    nombreAdmin: '',
    correoAdmin: '',
    passwordAdmin: '',
    metodoPago: 'MERCADO_PAGO',
    meses: 1
  };

  constructor(private saas: SaasService, private auth: AuthService, private router: Router) {}

  ngOnInit(): void {
    this.sesionActiva = this.auth.isLoggedIn();
    if (this.sesionActiva) {
      this.correoSesion = this.auth.getCorreo();
      this.form.correoAdmin = this.correoSesion;
      this.form.nombreAdmin = this.auth.getName();
      this.form.correoContacto = this.correoSesion;
    }
    this.saas.planesPublicos().subscribe({
      next: (planes) => {
        this.planes = planes;
        const basico = planes.find((p) => p.nombre.toUpperCase().includes('BASICO')) || planes[0];
        if (basico) this.form.planId = basico.id;
      },
      error: () => (this.errorMsg = 'No se pudieron cargar los planes. Intente nuevamente.')
    });
  }

  seleccionarPlan(plan: Plan): void {
    this.form.planId = plan.id;
  }

  onSubmit(): void {
    this.errorMsg = '';
    if (!this.form.planId) {
      this.errorMsg = 'Seleccione un plan.';
      return;
    }
    this.enviando = true;
    if (this.sesionActiva) {
      this.agregarAMiCuenta();
      return;
    }
    this.saas.registrarEmpresa({ ...this.form, planId: this.form.planId } as any).subscribe({
      next: (respuesta) => {
        this.enviando = false;
        this.exito = respuesta;
      },
      error: (error) => {
        this.enviando = false;
        this.errorMsg = error.error?.message || 'El registro falló. Revise los datos e intente nuevamente.';
      }
    });
  }

  /** Agrega la empresa a la cuenta ya autenticada y cambia a ella. */
  private agregarAMiCuenta(): void {
    this.auth
      .agregarEmpresa({
        nombreEmpresa: this.form.nombreEmpresa,
        nit: this.form.nit,
        rubro: this.form.rubro,
        correoContacto: this.form.correoContacto,
        planId: this.form.planId as number
      })
      .subscribe({
        next: (respuesta) => {
          this.enviando = false;
          this.exito = { ...respuesta, plan: 'prueba', referenciaPago: '-' };
          this.empresaNuevaId = respuesta.empresaId;
          // Cambia a la empresa nueva: el backend emite un token con ese rol.
          this.auth.cambiarEmpresa(respuesta.empresaId).subscribe({
            next: () => window.location.reload(),
            error: () => this.irAMiEmpresa()
          });
        },
        error: (error) => {
          this.enviando = false;
          this.errorMsg =
            error.error?.message || 'No se pudo agregar la empresa. Revise los datos e intente nuevamente.';
        }
      });
  }

  /** Vuelve a la pantalla principal (ya dentro de la empresa nueva). */
  irAMiEmpresa(): void {
    this.router.navigate(['/']);
  }
}
