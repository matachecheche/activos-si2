#
# llenar_datos_prueba.ps1
# - Agrega activos, ubicaciones y asignaciones ficticias a la base de datos.
# - Agrega endpoints de solo lectura para categorias/ubicaciones (dropdowns).
# - Mejora la interfaz: navbar, estilos globales, formulario de activos con
#   categoria en desplegable en vez de escribir el ID a mano.
# Idempotente: se puede correr varias veces sin romper nada.
#

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Write-Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    AVISO: $msg" -ForegroundColor Yellow }

function Write-FileNoBom($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Remove-Bom($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        [System.IO.File]::WriteAllBytes($path, $bytes[3..($bytes.Length - 1)])
    }
}
function Remove-BomFromFolder($folder, $extensions) {
    if (-not (Test-Path $folder)) { return }
    Get-ChildItem -Path $folder -Recurse -File | Where-Object { $extensions -contains $_.Extension } | ForEach-Object {
        Remove-Bom $_.FullName
    }
}

$backendDir  = Join-Path $root "backend"
$frontendDir = Join-Path $root "frontend"

if (-not (Test-Path $backendDir) -or -not (Test-Path $frontendDir)) {
    Write-Warn2 "No se encontraron las carpetas backend\ y frontend\ junto a este script."
    Write-Warn2 "Coloca este .bat/.ps1 en la misma carpeta donde generaste el proyecto."
    Read-Host "Presiona Enter para salir"
    exit 1
}

$srcMain = Join-Path $backendDir "src\main\java\com\uagrm\activos"
$appDir  = Join-Path $frontendDir "src\app"

# ---------------------------------------------------------------------------
# 1. Backend: endpoints de solo lectura para categorias y ubicaciones
# ---------------------------------------------------------------------------
Write-Step "Agregando endpoints de categorias y ubicaciones"

if (Test-Path $srcMain) {

@'
package com.uagrm.activos.controller;

import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.repository.CategoriaRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categorias")
public class CategoriaController {

    private final CategoriaRepository categoriaRepository;

    public CategoriaController(CategoriaRepository categoriaRepository) {
        this.categoriaRepository = categoriaRepository;
    }

    @GetMapping
    public List<Categoria> listar() {
        return categoriaRepository.findAll();
    }
}
'@ | Set-Content (Join-Path $srcMain "controller\CategoriaController.java") -Encoding UTF8

@'
package com.uagrm.activos.controller;

import com.uagrm.activos.model.Ubicacion;
import com.uagrm.activos.repository.UbicacionRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ubicaciones")
public class UbicacionController {

    private final UbicacionRepository ubicacionRepository;

    public UbicacionController(UbicacionRepository ubicacionRepository) {
        this.ubicacionRepository = ubicacionRepository;
    }

    @GetMapping
    public List<Ubicacion> listar() {
        return ubicacionRepository.findAll();
    }
}
'@ | Set-Content (Join-Path $srcMain "controller\UbicacionController.java") -Encoding UTF8

    Remove-BomFromFolder $backendDir @(".java")
    Write-Ok "CategoriaController y UbicacionController agregados"
} else {
    Write-Warn2 "No se encontro backend\src\main\java\com\uagrm\activos ; se omite este paso"
}

# ---------------------------------------------------------------------------
# 2. Base de datos: datos ficticios
# ---------------------------------------------------------------------------
Write-Step "Preparando datos ficticios"

$seedContent = @'
-- Datos ficticios para probar la interfaz (Sprint 1)
-- Seguro de correr varias veces: usa ON CONFLICT / valida antes de insertar.

INSERT INTO ubicacion (nombre) VALUES
    ('Almacen central'),
    ('Oficina de sistemas'),
    ('Laboratorio de redes'),
    ('Direccion administrativa'),
    ('Biblioteca')
ON CONFLICT DO NOTHING;

-- Activos ficticios (solo se insertan si la tabla activo tiene menos de 5 registros,
-- para no duplicar si ya corriste este script antes)
DO $$
DECLARE
    cnt INT;
    cat_mobiliario INT;
    cat_equipos INT;
    cat_vehiculos INT;
    cat_maquinaria INT;
    cat_inmuebles INT;
BEGIN
    SELECT COUNT(*) INTO cnt FROM activo;
    IF cnt < 5 THEN
        SELECT id INTO cat_mobiliario FROM categoria WHERE nombre = 'Mobiliario';
        SELECT id INTO cat_equipos FROM categoria WHERE nombre = 'Equipos informaticos';
        SELECT id INTO cat_vehiculos FROM categoria WHERE nombre = 'Vehiculos';
        SELECT id INTO cat_maquinaria FROM categoria WHERE nombre = 'Maquinaria';
        SELECT id INTO cat_inmuebles FROM categoria WHERE nombre = 'Inmuebles';

        INSERT INTO activo (codigo, nombre, categoria_id, valor, fecha_adquisicion, proveedor, estado)
        VALUES
            ('ACT-2026-0001', 'Laptop Dell Latitude 5440', cat_equipos, 8500.00, '2026-01-15', 'Tecnodata SRL', 'SIN_ASIGNAR'),
            ('ACT-2026-0002', 'Laptop HP ProBook 450', cat_equipos, 7900.00, '2026-01-15', 'Tecnodata SRL', 'SIN_ASIGNAR'),
            ('ACT-2026-0003', 'Impresora multifuncional Epson L5590', cat_equipos, 2300.00, '2026-02-02', 'Comercial Andina', 'SIN_ASIGNAR'),
            ('ACT-2026-0004', 'Proyector Epson PowerLite X49', cat_equipos, 3200.00, '2026-02-10', 'Comercial Andina', 'MANTENIMIENTO'),
            ('ACT-2026-0005', 'Escritorio ejecutivo de melamina', cat_mobiliario, 950.00, '2026-01-20', 'Muebleria San Martin', 'SIN_ASIGNAR'),
            ('ACT-2026-0006', 'Silla ergonomica giratoria', cat_mobiliario, 480.00, '2026-01-20', 'Muebleria San Martin', 'SIN_ASIGNAR'),
            ('ACT-2026-0007', 'Archivador metalico 4 gavetas', cat_mobiliario, 620.00, '2026-01-25', 'Muebleria San Martin', 'SIN_ASIGNAR'),
            ('ACT-2026-0008', 'Vehiculo Toyota Hilux 2024', cat_vehiculos, 245000.00, '2026-03-05', 'Toyotasa', 'SIN_ASIGNAR'),
            ('ACT-2026-0009', 'Motocicleta Honda CB125', cat_vehiculos, 12500.00, '2026-03-10', 'Motos del Oriente', 'BAJA'),
            ('ACT-2026-0010', 'Generador electrico 5kva', cat_maquinaria, 9800.00, '2026-02-18', 'Ferreteria Central', 'SIN_ASIGNAR'),
            ('ACT-2026-0011', 'Aire acondicionado split 24000 BTU', cat_maquinaria, 5400.00, '2026-02-20', 'ClimaTech', 'SIN_ASIGNAR'),
            ('ACT-2026-0012', 'Edificio Bloque C - Facultad', cat_inmuebles, 1850000.00, '2020-01-01', 'N/A', 'SIN_ASIGNAR')
        ON CONFLICT (codigo) DO NOTHING;
    END IF;
END $$;

-- Asignaciones ficticias: se asignan algunos activos a los usuarios de prueba
DO $$
DECLARE
    u_encargado INT;
    u_contador INT;
    ub_oficina INT;
    ub_almacen INT;
    act1 INT;
    act2 INT;
BEGIN
    SELECT id INTO u_encargado FROM usuario WHERE correo = 'encargado@uagrm.edu.bo';
    SELECT id INTO u_contador  FROM usuario WHERE correo = 'contador@uagrm.edu.bo';
    SELECT id INTO ub_oficina  FROM ubicacion WHERE nombre = 'Oficina de sistemas';
    SELECT id INTO ub_almacen  FROM ubicacion WHERE nombre = 'Almacen central';
    SELECT id INTO act1 FROM activo WHERE codigo = 'ACT-2026-0001';
    SELECT id INTO act2 FROM activo WHERE codigo = 'ACT-2026-0005';

    IF u_encargado IS NOT NULL AND act1 IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM asignacion WHERE activo_id = act1 AND activa = TRUE) THEN
        INSERT INTO asignacion (activo_id, responsable_id, ubicacion_id, fecha_asignacion, activa)
        VALUES (act1, u_encargado, ub_oficina, NOW(), TRUE);
        UPDATE activo SET responsable_id = u_encargado, ubicacion_id = ub_oficina, estado = 'EN_USO' WHERE id = act1;
    END IF;

    IF u_contador IS NOT NULL AND act2 IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM asignacion WHERE activo_id = act2 AND activa = TRUE) THEN
        INSERT INTO asignacion (activo_id, responsable_id, ubicacion_id, fecha_asignacion, activa)
        VALUES (act2, u_contador, ub_almacen, NOW(), TRUE);
        UPDATE activo SET responsable_id = u_contador, ubicacion_id = ub_almacen, estado = 'EN_USO' WHERE id = act2;
    END IF;
END $$;
'@
Write-FileNoBom (Join-Path $root "database\seed_datos_ficticios.sql") $seedContent
Write-Ok "database\seed_datos_ficticios.sql generado"

$hasPsql = $null -ne (Get-Command psql -ErrorAction SilentlyContinue)

if ($hasPsql) {
    $dbName = "activos_fijos_db"
    $dbUser = Read-Host "Usuario de PostgreSQL [postgres]"
    if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = "postgres" }
    $dbPassSecure = Read-Host "Contrasena de PostgreSQL para '$dbUser'" -AsSecureString
    $dbPassBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassSecure)
    $dbPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($dbPassBstr)
    $dbHost = Read-Host "Host de PostgreSQL [localhost]"
    if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = "localhost" }
    $dbPort = Read-Host "Puerto de PostgreSQL [5432]"
    if ([string]::IsNullOrWhiteSpace($dbPort)) { $dbPort = "5432" }

    $env:PGPASSWORD = $dbPass
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -f (Join-Path $root "database\seed_datos_ficticios.sql") 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Datos ficticios aplicados en '$dbName'"
        } else {
            Write-Warn2 "Hubo errores al aplicar los datos ficticios (revisa arriba)"
        }
    } catch {
        Write-Warn2 "Error al conectar con PostgreSQL: $_"
    } finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
        $ErrorActionPreference = $prevEAP
    }
} else {
    Write-Warn2 "No se encontro 'psql' en el PATH. Corre manualmente database\seed_datos_ficticios.sql en tu base."
}

# ---------------------------------------------------------------------------
# 3. Frontend: interfaz mas amigable
# ---------------------------------------------------------------------------
Write-Step "Mejorando la interfaz"

if (Test-Path $appDir) {

    # Estilos globales
    $stylesPath = Join-Path $frontendDir "src\styles.scss"
@'
* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: "Segoe UI", system-ui, sans-serif;
  background: #f4f6f8;
  color: #1f2a37;
}

a {
  color: inherit;
}

button {
  font-family: inherit;
}
'@ | Set-Content $stylesPath -Encoding UTF8

    # Navbar (app.component)
@'
import { Component } from '@angular/core';
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
}
'@ | Set-Content (Join-Path $appDir "app.component.ts") -Encoding UTF8

@'
<header class="navbar" *ngIf="authService.isLoggedIn()">
  <div class="navbar-title">Activos Fijos y Presupuestos</div>
  <nav>
    <a routerLink="/activos">Activos</a>
    <button (click)="cerrarSesion()">Cerrar sesion</button>
  </nav>
</header>

<main class="content">
  <router-outlet />
</main>
'@ | Set-Content (Join-Path $appDir "app.component.html") -Encoding UTF8

@'
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 24px;
  background: #1f2a37;
  color: #fff;

  .navbar-title {
    font-weight: 600;
  }

  nav {
    display: flex;
    align-items: center;
    gap: 16px;

    a {
      color: #fff;
      text-decoration: none;
      font-size: 14px;

      &:hover {
        text-decoration: underline;
      }
    }

    button {
      background: transparent;
      border: 1px solid #fff;
      color: #fff;
      padding: 6px 12px;
      border-radius: 4px;
      cursor: pointer;

      &:hover {
        background: #fff;
        color: #1f2a37;
      }
    }
  }
}

.content {
  max-width: 960px;
  margin: 24px auto;
  padding: 0 16px;
}
'@ | Set-Content (Join-Path $appDir "app.component.scss") -Encoding UTF8

    # Categoria model + service
    $modelsDir = Join-Path $appDir "core\models"
@'
export interface Categoria {
  id: number;
  nombre: string;
}
'@ | Set-Content (Join-Path $modelsDir "categoria.model.ts") -Encoding UTF8

$categoriaServiceDir = Join-Path $appDir "core\services"
if (-not (Test-Path $categoriaServiceDir)) { New-Item -ItemType Directory -Path $categoriaServiceDir | Out-Null }

@'
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Categoria } from '../models/categoria.model';

@Injectable({ providedIn: 'root' })
export class CategoriaService {
  constructor(private http: HttpClient) {}

  listar(): Observable<Categoria[]> {
    return this.http.get<Categoria[]>(`${environment.apiUrl}/categorias`);
  }
}
'@ | Set-Content (Join-Path $categoriaServiceDir "categoria.service.ts") -Encoding UTF8

    # activos.component mas amigable: categoria en desplegable + estado con color
@'
import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivoService } from './activo.service';
import { Activo } from '../../core/models/activo.model';
import { Categoria } from '../../core/models/categoria.model';
import { CategoriaService } from '../../core/services/categoria.service';

@Component({
  selector: 'app-activos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './activos.component.html',
  styleUrl: './activos.component.scss'
})
export class ActivosComponent implements OnInit {
  activos: Activo[] = [];
  categorias: Categoria[] = [];
  mostrarFormulario = false;

  nuevo: Activo = {
    nombre: '',
    categoriaId: 0,
    valor: 0,
    fechaAdquisicion: ''
  };

  constructor(
    private activoService: ActivoService,
    private categoriaService: CategoriaService
  ) {}

  ngOnInit(): void {
    this.cargarActivos();
    this.categoriaService.listar().subscribe((data) => {
      this.categorias = data;
      if (data.length) { this.nuevo.categoriaId = data[0].id; }
    });
  }

  cargarActivos(): void {
    this.activoService.listar().subscribe((data) => (this.activos = data));
  }

  nombreCategoria(id: number): string {
    return this.categorias.find((c) => c.id === id)?.nombre ?? '-';
  }

  claseEstado(estado?: string): string {
    switch (estado) {
      case 'EN_USO': return 'badge badge-uso';
      case 'MANTENIMIENTO': return 'badge badge-mantenimiento';
      case 'BAJA': return 'badge badge-baja';
      default: return 'badge badge-sin-asignar';
    }
  }

  registrar(): void {
    this.activoService.registrar(this.nuevo).subscribe(() => {
      this.nuevo = {
        nombre: '',
        categoriaId: this.categorias[0]?.id ?? 0,
        valor: 0,
        fechaAdquisicion: ''
      };
      this.mostrarFormulario = false;
      this.cargarActivos();
    });
  }
}
'@ | Set-Content (Join-Path $appDir "features\activos\activos.component.ts") -Encoding UTF8

@'
<div class="page-header">
  <h2>Activos fijos</h2>
  <button class="btn-primary" (click)="mostrarFormulario = !mostrarFormulario">
    {{ mostrarFormulario ? 'Cancelar' : '+ Nuevo activo' }}
  </button>
</div>

<form *ngIf="mostrarFormulario" (ngSubmit)="registrar()" class="card form-grid">
  <div class="field">
    <label>Nombre</label>
    <input placeholder="Nombre del activo" name="nombre" [(ngModel)]="nuevo.nombre" required />
  </div>

  <div class="field">
    <label>Categoria</label>
    <select name="categoriaId" [(ngModel)]="nuevo.categoriaId" required>
      <option *ngFor="let c of categorias" [value]="c.id">{{ c.nombre }}</option>
    </select>
  </div>

  <div class="field">
    <label>Valor (Bs)</label>
    <input placeholder="0.00" type="number" step="0.01" name="valor" [(ngModel)]="nuevo.valor" required />
  </div>

  <div class="field">
    <label>Fecha de adquisicion</label>
    <input type="date" name="fechaAdquisicion" [(ngModel)]="nuevo.fechaAdquisicion" required />
  </div>

  <div class="field span-2">
    <label>Proveedor</label>
    <input placeholder="Proveedor (opcional)" name="proveedor" [(ngModel)]="nuevo.proveedor" />
  </div>

  <div class="field span-2 actions">
    <button type="submit" class="btn-primary">Guardar activo</button>
  </div>
</form>

<div class="card">
  <table>
    <thead>
      <tr>
        <th>Codigo</th>
        <th>Nombre</th>
        <th>Categoria</th>
        <th>Valor (Bs)</th>
        <th>Estado</th>
      </tr>
    </thead>
    <tbody>
      <tr *ngFor="let a of activos">
        <td>{{ a.codigo }}</td>
        <td>{{ a.nombre }}</td>
        <td>{{ nombreCategoria(a.categoriaId) }}</td>
        <td>{{ a.valor | number: '1.2-2' }}</td>
        <td><span [class]="claseEstado(a.estado)">{{ a.estado }}</span></td>
      </tr>
      <tr *ngIf="!activos.length">
        <td colspan="5" class="empty">No hay activos registrados todavia.</td>
      </tr>
    </tbody>
  </table>
</div>
'@ | Set-Content (Join-Path $appDir "features\activos\activos.component.html") -Encoding UTF8

@'
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;

  h2 {
    margin: 0;
  }
}

.btn-primary {
  background: #2563eb;
  color: #fff;
  border: none;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;

  &:hover {
    background: #1d4ed8;
  }
}

.card {
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
  padding: 16px;
  margin-bottom: 16px;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px 16px;

  .field {
    display: flex;
    flex-direction: column;
    gap: 4px;

    label {
      font-size: 13px;
      color: #6b7280;
    }

    input, select {
      padding: 8px;
      border: 1px solid #d1d5db;
      border-radius: 6px;
      font-size: 14px;
    }
  }

  .span-2 {
    grid-column: span 2;
  }

  .actions {
    justify-content: flex-end;
  }
}

table {
  width: 100%;
  border-collapse: collapse;

  th, td {
    padding: 10px 12px;
    text-align: left;
    border-bottom: 1px solid #e5e7eb;
    font-size: 14px;
  }

  th {
    color: #6b7280;
    font-weight: 600;
    font-size: 12px;
    text-transform: uppercase;
  }

  tr:hover td {
    background: #f9fafb;
  }

  .empty {
    text-align: center;
    color: #9ca3af;
    padding: 24px;
  }
}

.badge {
  display: inline-block;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
}

.badge-uso { background: #dcfce7; color: #166534; }
.badge-mantenimiento { background: #fef3c7; color: #92400e; }
.badge-baja { background: #fee2e2; color: #991b1b; }
.badge-sin-asignar { background: #e5e7eb; color: #374151; }
'@ | Set-Content (Join-Path $appDir "features\activos\activos.component.scss") -Encoding UTF8

    Remove-BomFromFolder $appDir @(".ts", ".html", ".scss")
    Remove-Bom $stylesPath
    Write-Ok "Interfaz mejorada: navbar, estilos globales y activos con categoria en desplegable"
} else {
    Write-Warn2 "No se encontro frontend\src\app ; se omite la mejora de interfaz"
}

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Listo"  -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " - Se agregaron datos ficticios (activos, ubicaciones, asignaciones)"
Write-Host " - Se agregaron endpoints GET /api/categorias y /api/ubicaciones"
Write-Host " - Se mejoro la interfaz (navbar, estilos, categoria en desplegable)"
Write-Host ""
Write-Host " Si el backend ya estaba corriendo, reinicialo para que tome"
Write-Host " los nuevos endpoints (Ctrl+C en su ventana y volver a: mvn spring-boot:run)"
Write-Host ""
