import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { SaasService } from './saas.service';
import { Plan } from '../../core/models/sprint3.models';

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

  constructor(private saas: SaasService) {}

  ngOnInit(): void {
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
}
