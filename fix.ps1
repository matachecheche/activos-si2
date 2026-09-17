<#
  fix.ps1
  Arregla los problemas detectados en el Sprint 1 del proyecto
  "Sistema de Activos Fijos y Presupuestos" (Grupo 7 - UAGRM):

    1) Limpia el cache de compilacion de Maven (causa del error de Lombok
       "cannot find symbol" en getters/setters/builder).
    2) Siembra (o repara) 4 usuarios de prueba, uno por rol, y los
       desbloquea si habian quedado bloqueados por intentos fallidos.
    3) Deja app.component.html solo con el <router-outlet>, quitando el
       texto de bienvenida por defecto de Angular.
    4) Actualiza la pantalla de login para que muestre los usuarios de
       prueba sugeridos, con botones para autocompletar el formulario.

  Es idempotente: se puede volver a ejecutar sin romper nada.
#>

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Write-Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    AVISO: $msg" -ForegroundColor Yellow }
function Write-Err2($msg) { Write-Host "    ERROR: $msg" -ForegroundColor Red }

function Write-FileNoBom($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

$backendDir  = Join-Path $root "backend"
$frontendDir = Join-Path $root "frontend"
$appDir      = Join-Path $frontendDir "src\app"

Write-Host "====================================================="
Write-Host " Arreglo de problemas - Sistema de Activos Fijos"
Write-Host " y Presupuestos - Grupo 7 (UAGRM - FICCT)"
Write-Host "====================================================="

# ---------------------------------------------------------------------------
# 1. Limpiar el build de Maven (problema de Lombok / cache incremental)
# ---------------------------------------------------------------------------
Write-Step "Limpiando el build del backend (mvn clean)"

if (-not (Test-Path $backendDir)) {
    Write-Warn2 "No se encontro la carpeta 'backend' junto a este script. Se omite este paso."
} else {
    Push-Location $backendDir
    where.exe mvn *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "No se encontro 'mvn' en el PATH. Corre 'mvn clean' manualmente dentro de backend\."
    } else {
        & mvn clean *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "target\ limpiado correctamente"
        } else {
            Write-Warn2 "mvn clean devolvio un error. Revisa manualmente con 'mvn clean' dentro de backend\."
        }
    }
    Pop-Location
}

# ---------------------------------------------------------------------------
# 2. Sembrar / reparar usuarios de prueba
# ---------------------------------------------------------------------------
Write-Step "Preparando usuarios de prueba (uno por rol)"

# Las contrasenas ya estan cifradas con BCrypt (10 rounds). No se generan
# en caliente para no depender de tener Java/BCrypt disponible en este equipo.
#   admin@uagrm.edu.bo       -> admin123        (ADMINISTRADOR)
#   encargado@uagrm.edu.bo   -> encargado123    (ENCARGADO_ACTIVOS)
#   contador@uagrm.edu.bo    -> contador123     (CONTADOR)
#   financiero@uagrm.edu.bo  -> financiero123   (RESPONSABLE_FINANCIERO)
$sqlUsuarios = @'
-- Usuarios de prueba (uno por rol). Si el correo ya existe, se actualiza
-- la contrasena y se desbloquea la cuenta (intentos_fallidos = 0).
INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Administrador (prueba)', 'admin@uagrm.edu.bo',
       '$2b$10$Vn.kCG30k/5rvSbwY9jPI.ZXSMnmtzZSAH.Lrxb7cFHzUfNyEcScy',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'ADMINISTRADOR'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;

INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Encargado de Activos (prueba)', 'encargado@uagrm.edu.bo',
       '$2b$10$Hmr7ACmODagliVeslQB82eOX.Cfq7gpaxuJ2N9pH5SA2WdoVwnmSC',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'ENCARGADO_ACTIVOS'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;

INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Contador (prueba)', 'contador@uagrm.edu.bo',
       '$2b$10$R4KjaSKjvE6j7l/bAwOmLOWzf7P3J6/qZy8GFhDlw3doLlVijztOi',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'CONTADOR'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;

INSERT INTO usuario (nombre, correo, password, rol_id, intentos_fallidos, bloqueado_hasta, activo)
SELECT 'Responsable Financiero (prueba)', 'financiero@uagrm.edu.bo',
       '$2b$10$R4DyovKsPU52RcaD4o6eAuVSQ9ZPJh.363GlQDLw8d/U4zp17Dgvu',
       r.id, 0, NULL, true
FROM rol r WHERE r.nombre = 'RESPONSABLE_FINANCIERO'
ON CONFLICT (correo) DO UPDATE SET
    password = EXCLUDED.password,
    intentos_fallidos = 0,
    bloqueado_hasta = NULL,
    activo = true;
'@

$sqlPath = Join-Path $root "database\fix_usuarios_prueba.sql"
Write-FileNoBom $sqlPath $sqlUsuarios
Write-Ok "database\fix_usuarios_prueba.sql generado"

where.exe psql *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "No se encontro 'psql' en el PATH. Aplica el archivo manualmente:"
    Write-Warn2 "  psql -U <usuario> -d activos_fijos_db -f `"$sqlPath`""
} else {
    $dbName = "activos_fijos_db"
    $dbUser = Read-Host "Usuario de PostgreSQL [postgres]"
    if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = "postgres" }

    $dbPassSecure = Read-Host "Contrasena de PostgreSQL para '$dbUser'" -AsSecureString
    $dbPassBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassSecure)
    $dbPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($dbPassBstr)

    $env:PGPASSWORD = $dbPass
    & psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -f $sqlPath
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Usuarios de prueba sembrados/actualizados en '$dbName'"
    } else {
        Write-Err2 "psql devolvio un error al aplicar $sqlPath (revisa el detalle arriba)"
    }
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# 3. Limpiar app.component.html (quitar el boilerplate de Angular)
# ---------------------------------------------------------------------------
Write-Step "Limpiando app.component.html"

$appComponentHtml = Join-Path $appDir "app.component.html"
if (Test-Path $appComponentHtml) {
    Write-FileNoBom $appComponentHtml "<router-outlet></router-outlet>`n"
    Write-Ok "app.component.html actualizado (solo router-outlet)"
} else {
    Write-Warn2 "No se encontro $appComponentHtml ; se omite este paso."
}

# ---------------------------------------------------------------------------
# 4. Login con usuarios de prueba sugeridos
# ---------------------------------------------------------------------------
Write-Step "Actualizando la pantalla de login con usuarios sugeridos"

$loginDir = Join-Path $appDir "features\login"

if (-not (Test-Path $loginDir)) {
    Write-Warn2 "No se encontro $loginDir ; se omite este paso."
} else {
@'
import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';

interface UsuarioPrueba {
  rol: string;
  correo: string;
  password: string;
}

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent {
  correo = '';
  password = '';
  errorMsg = '';

  // Usuarios de prueba sembrados por fix.ps1 (ver database/fix_usuarios_prueba.sql).
  // Solo para pruebas del Sprint 1: quitar antes de un entorno real.
  usuariosPrueba: UsuarioPrueba[] = [
    { rol: 'ADMINISTRADOR', correo: 'admin@uagrm.edu.bo', password: 'admin123' },
    { rol: 'ENCARGADO_ACTIVOS', correo: 'encargado@uagrm.edu.bo', password: 'encargado123' },
    { rol: 'CONTADOR', correo: 'contador@uagrm.edu.bo', password: 'contador123' },
    { rol: 'RESPONSABLE_FINANCIERO', correo: 'financiero@uagrm.edu.bo', password: 'financiero123' }
  ];

  constructor(private authService: AuthService, private router: Router) {}

  usarUsuario(u: UsuarioPrueba): void {
    this.correo = u.correo;
    this.password = u.password;
  }

  onSubmit(): void {
    this.errorMsg = '';
    this.authService.login(this.correo, this.password).subscribe({
      next: () => this.router.navigate(['/activos']),
      error: () => (this.errorMsg = 'Credenciales invalidas o cuenta bloqueada')
    });
  }
}
'@ | Set-Content (Join-Path $loginDir "login.component.ts") -Encoding UTF8

@'
<div class="login-container">
  <h2>Iniciar sesion</h2>
  <form (ngSubmit)="onSubmit()">
    <label>Correo institucional</label>
    <input type="email" name="correo" [(ngModel)]="correo" required />

    <label>Contrasena</label>
    <input type="password" name="password" [(ngModel)]="password" required />

    <p class="error" *ngIf="errorMsg">{{ errorMsg }}</p>

    <button type="submit">Ingresar</button>
  </form>

  <div class="usuarios-prueba">
    <p class="usuarios-prueba__titulo">Usuarios de prueba (Sprint 1)</p>
    <ul>
      <li *ngFor="let u of usuariosPrueba">
        <span class="rol">{{ u.rol }}</span>
        <span class="credenciales">{{ u.correo }} / {{ u.password }}</span>
        <button type="button" class="btn-usar" (click)="usarUsuario(u)">Usar</button>
      </li>
    </ul>
  </div>
</div>
'@ | Set-Content (Join-Path $loginDir "login.component.html") -Encoding UTF8

@'
.login-container {
  max-width: 420px;
  margin: 80px auto;
  padding: 24px;
  border: 1px solid #ddd;
  border-radius: 8px;

  form {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .error {
    color: #c0392b;
  }
}

.usuarios-prueba {
  margin-top: 24px;
  padding-top: 16px;
  border-top: 1px dashed #ccc;
  font-size: 13px;

  &__titulo {
    font-weight: bold;
    margin-bottom: 8px;
    color: #555;
  }

  ul {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  li {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    background: #f7f7f7;
    padding: 6px 8px;
    border-radius: 4px;
  }

  .rol {
    font-weight: 600;
    color: #333;
  }

  .credenciales {
    color: #666;
    flex: 1;
    text-align: left;
    margin-left: 8px;
  }

  .btn-usar {
    padding: 2px 10px;
    cursor: pointer;
  }
}
'@ | Set-Content (Join-Path $loginDir "login.component.scss") -Encoding UTF8

    Write-Ok "login.component.ts / .html / .scss actualizados con usuarios sugeridos"
}

Write-Host ""
Write-Host "====================================================="
Write-Host " Listo. Resumen:"
Write-Host "  1) backend\ limpiado (mvn clean)."
Write-Host "  2) 4 usuarios de prueba sembrados/desbloqueados."
Write-Host "  3) app.component.html deja de mostrar el boilerplate de Angular."
Write-Host "  4) La pantalla de login ahora sugiere los usuarios de prueba."
Write-Host ""
Write-Host " Siguiente paso:"
Write-Host "  - backend: cd backend; mvn spring-boot:run"
Write-Host "  - frontend: cd frontend; ng serve"
Write-Host "  - abrir http://localhost:4200/login"
Write-Host "====================================================="
