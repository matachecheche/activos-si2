#
# capturar_proyecto.ps1
# Empaqueta el estado ACTUAL del proyecto (tal cual esta en esta carpeta,
# con tus modificaciones incluidas) dentro de un script autocontenido
# (restaurar_proyecto_actual.ps1 + .bat) que puede reconstruirlo identico
# en cualquier otra maquina, sin necesitar internet.
#
# Tambien detecta y reporta que herramientas hacen falta para correr el
# proyecto (Java, Maven, Node, npm, PostgreSQL/psql, Git) y sus versiones.
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

# ---------------------------------------------------------------------------
# 1. Detectar herramientas instaladas en ESTA maquina (donde se hace la captura)
# ---------------------------------------------------------------------------
Write-Step "Detectando herramientas instaladas en este equipo"

function Get-VersionTexto($comando, $args2) {
    if (-not (Get-Command $comando -ErrorAction SilentlyContinue)) { return "no detectado" }
    try {
        $out = & $comando @args2 2>&1 | Select-Object -First 1
        return "$out"
    } catch { return "no se pudo determinar la version" }
}

$verJava = Get-VersionTexto "java" @("-version")
$verMvn  = Get-VersionTexto "mvn" @("-v")
$verNode = Get-VersionTexto "node" @("-v")
$verNpm  = Get-VersionTexto "npm" @("-v")
$verPsql = Get-VersionTexto "psql" @("--version")
$verGit  = Get-VersionTexto "git" @("--version")

Write-Ok "Java   : $verJava"
Write-Ok "Maven  : $verMvn"
Write-Ok "Node   : $verNode"
Write-Ok "npm    : $verNpm"
Write-Ok "psql   : $verPsql"
Write-Ok "Git    : $verGit"

# ---------------------------------------------------------------------------
# 2. Recolectar los archivos del proyecto (excluyendo generados/pesados)
# ---------------------------------------------------------------------------
Write-Step "Recolectando archivos del proyecto"

# Carpetas que NUNCA se empaquetan (se regeneran solas o son pesadas/no portables)
$carpetasExcluidas = @(
    "\node_modules\", "\.angular\", "\dist\", "\target\", "\.git\",
    "\.vscode\", "\.idea\", "\.mvn\",
    # Flutter / Android / iOS (se regeneran con 'flutter create' + 'flutter pub get')
    "\build\", "\.dart_tool\", "\.gradle\", "\.pub-cache\", "\.plugin_symlinks\",
    "\Pods\", "\DerivedData\", "\ephemeral\",
    "\android\.gradle\", "\android\app\build\", "\android\build\",
    "\app\intermediates\", "\app\outputs\", "\app\.cxx\"
)

# Nombres de archivo que no se empaquetan (los propios scripts generadores,
# y cualquier salida previa de este mismo script)
$archivosExcluidosNombres = @(
    "capturar_proyecto.bat", "capturar_proyecto.ps1",
    "restaurar_proyecto_actual.bat", "restaurar_proyecto_actual.ps1",
    "REQUISITOS.txt", "local.properties"
)
$extensionesExcluidas = @(".zip", ".log", ".apk", ".aab", ".jar", ".class", ".iml")
$tamanoMaximoPorArchivoMb = 15   # archivos individuales mas grandes que esto se saltan (avisando)

$todos = Get-ChildItem -Path $root -Recurse -File

$incluidos = $todos | Where-Object {
    $rel = $_.FullName.Substring($root.Length)
    $excluidoPorCarpeta = $false
    foreach ($c in $carpetasExcluidas) {
        if ($rel -like "*$c*") { $excluidoPorCarpeta = $true; break }
    }
    -not $excluidoPorCarpeta `
        -and ($archivosExcluidosNombres -notcontains $_.Name) `
        -and ($extensionesExcluidas -notcontains $_.Extension)
}

# Aviso de archivos individuales pesados (no se incluyen, para evitar quedarse sin memoria)
$pesados = $incluidos | Where-Object { $_.Length -gt ($tamanoMaximoPorArchivoMb * 1MB) }
if ($pesados) {
    Write-Warn2 "Se omiten $($pesados.Count) archivo(s) de mas de $tamanoMaximoPorArchivoMb MB (no son codigo fuente, seguramente cachés/binarios):"
    foreach ($p in $pesados) {
        $rel = $p.FullName.Substring($root.Length + 1)
        $mb = [Math]::Round($p.Length / 1MB, 1)
        Write-Warn2 "  - $rel ($mb MB)"
    }
    $incluidos = $incluidos | Where-Object { $_.Length -le ($tamanoMaximoPorArchivoMb * 1MB) }
}

Write-Ok "Se van a empaquetar $($incluidos.Count) archivos"

if ($incluidos.Count -eq 0) {
    Write-Warn2 "No se encontro ningun archivo para empaquetar. Verifica que este script este junto a backend\, frontend\ y database\."
    Read-Host "Presiona Enter para salir"
    exit 1
}

# ---------------------------------------------------------------------------
# 3. Generar restaurar_proyecto_actual.ps1 escribiendo DIRECTO A DISCO
#    (no se arma un string gigante en memoria: se evita el OutOfMemoryException
#    que puede ocurrir con proyectos grandes o muchos archivos binarios)
# ---------------------------------------------------------------------------
Write-Step "Generando el script de restauracion (esto puede tardar unos segundos)"

$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"

$encabezado = @"
#
# restaurar_proyecto_actual.ps1
# Generado automaticamente el $fecha por capturar_proyecto.ps1
#
# Reconstruye el proyecto "Sistema de Activos Fijos y Presupuestos"
# EXACTAMENTE como estaba en el momento de la captura (con todas las
# modificaciones que tuviera hasta ese momento), en la carpeta donde
# se ejecute este script. No necesita internet: todo el codigo va
# embebido aqui mismo en Base64.
#
# Herramientas detectadas en el equipo donde se genero este paquete:
#   Java : $verJava
#   Maven: $verMvn
#   Node : $verNode
#   npm  : $verNpm
#   psql : $verPsql
#   Git  : $verGit
#
# NOTA: node_modules, target, build, .gradle, .dart_tool y similares NO se
# incluyen (son generados y muy pesados). Este script ofrece correr
# 'npm install' / 'flutter pub get' despues de restaurar los archivos.
#

`$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
`$root = Split-Path -Parent `$MyInvocation.MyCommand.Path
Set-Location `$root

function Write-Step(`$msg) { Write-Host ""; Write-Host "==> `$msg" -ForegroundColor Cyan }
function Write-Ok(`$msg)   { Write-Host "    OK: `$msg" -ForegroundColor Green }
function Write-Warn2(`$msg){ Write-Host "    AVISO: `$msg" -ForegroundColor Yellow }

function Test-Cmd(`$name) {
    `$null = Get-Command `$name -ErrorAction SilentlyContinue
    return `$?
}

"@

$rutaSalida = Join-Path $root "restaurar_proyecto_actual.ps1"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$writer = New-Object System.IO.StreamWriter($rutaSalida, $false, $utf8NoBom)

try {
    $writer.Write($encabezado)
    $writer.WriteLine('$archivos = @(')

    $pesoTotal = 0
    $contador = 0
    foreach ($f in $incluidos) {
        $rel = $f.FullName.Substring($root.Length + 1)
        $relPs = $rel.Replace("'", "''")
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $pesoTotal += $bytes.Length
        $b64 = [Convert]::ToBase64String($bytes)
        $writer.WriteLine("    @{ Path = '$relPs'; B64 = '$b64' }")
        $contador++
        if ($contador % 200 -eq 0) { Write-Host "    ... $contador / $($incluidos.Count) archivos procesados" }
    }
    $writer.WriteLine(')')

    $pesoMb = [Math]::Round($pesoTotal / 1MB, 2)
    Write-Ok "Peso total empaquetado: $pesoMb MB ($contador archivos)"

$cuerpoRestauracion = @'

# ---------------------------------------------------------------------------
# 1. Verificacion de requisitos para CORRER el proyecto restaurado
# ---------------------------------------------------------------------------
Write-Step "Verificando requisitos en este equipo"

$hasJava = Test-Cmd "java"
$hasMvn  = Test-Cmd "mvn"
$hasNode = Test-Cmd "node"
$hasNpm  = Test-Cmd "npm"
$hasPsql = Test-Cmd "psql"
$hasGit  = Test-Cmd "git"

$requisitos = @(
    @{ Nombre = "Java 17 o superior (JDK)";        Presente = $hasJava; Instalar = "https://adoptium.net/  o  winget install EclipseAdoptium.Temurin.17.JDK" },
    @{ Nombre = "Maven 3.8 o superior";             Presente = $hasMvn;  Instalar = "https://maven.apache.org/download.cgi  o  winget install Apache.Maven" },
    @{ Nombre = "Node.js 18 o superior";            Presente = $hasNode; Instalar = "https://nodejs.org/  o  winget install OpenJS.NodeJS.LTS" },
    @{ Nombre = "npm (viene con Node.js)";          Presente = $hasNpm;  Instalar = "Se instala junto con Node.js" },
    @{ Nombre = "PostgreSQL 14+ (cliente psql)";    Presente = $hasPsql; Instalar = "https://www.postgresql.org/download/windows/  (agregar la carpeta bin al PATH)" },
    @{ Nombre = "Git (opcional, para versionar)";   Presente = $hasGit;  Instalar = "https://git-scm.com/download/win  o  winget install Git.Git" }
)

$faltantes = @()
foreach ($r in $requisitos) {
    if ($r.Presente) {
        Write-Ok "$($r.Nombre): instalado"
    } else {
        Write-Warn2 "$($r.Nombre): NO encontrado -> instalar desde $($r.Instalar)"
        $faltantes += $r
    }
}

if ($faltantes.Count -gt 0) {
    Write-Host ""
    Write-Warn2 "Faltan $($faltantes.Count) requisito(s). Podes seguir: los archivos se restauran igual,"
    Write-Warn2 "pero no vas a poder correr lo que dependa de la herramienta faltante hasta instalarla."
}

# ---------------------------------------------------------------------------
# 2. Restaurar todos los archivos embebidos
# ---------------------------------------------------------------------------
Write-Step "Restaurando $($archivos.Count) archivos del proyecto"

$sobrescribir = $true
$hayArchivosPrevios = (Test-Path (Join-Path $root "backend")) -or (Test-Path (Join-Path $root "frontend")) -or (Test-Path (Join-Path $root "database"))
if ($hayArchivosPrevios) {
    $resp = Read-Host "Ya existen carpetas backend/frontend/database aqui. Sobrescribir con la version capturada? (S/N) [S]"
    if ($resp -match '^[Nn]') { $sobrescribir = $false }
}

if ($sobrescribir) {
    foreach ($a in $archivos) {
        $destino = Join-Path $root $a.Path
        $carpetaDestino = Split-Path -Parent $destino
        if (-not (Test-Path $carpetaDestino)) { New-Item -ItemType Directory -Path $carpetaDestino -Force | Out-Null }
        $bytes = [Convert]::FromBase64String($a.B64)
        [System.IO.File]::WriteAllBytes($destino, $bytes)
    }
    Write-Ok "Archivos restaurados en $root"
} else {
    Write-Warn2 "Restauracion cancelada por el usuario"
    Read-Host "Presiona Enter para salir"
    exit 0
}

# ---------------------------------------------------------------------------
# 3. Dependencias del frontend (node_modules no viene incluido)
# ---------------------------------------------------------------------------
$frontendDir = Join-Path $root "frontend"
if ((Test-Path (Join-Path $frontendDir "package.json")) -and $hasNpm) {
    if (-not (Test-Path (Join-Path $frontendDir "node_modules"))) {
        $resp = Read-Host "Instalar dependencias del frontend ahora con 'npm install'? (S/N) [S]"
        if (-not ($resp -match '^[Nn]')) {
            Write-Step "Instalando dependencias del frontend"
            Push-Location $frontendDir
            npm install
            Pop-Location
            Write-Ok "Dependencias del frontend instaladas"
        }
    } else {
        Write-Ok "frontend\node_modules ya existe, se omite npm install"
    }
}

# ---------------------------------------------------------------------------
# 4. Base de datos (opcional)
# ---------------------------------------------------------------------------
$backendDir = Join-Path $root "backend"
$dbDir = Join-Path $root "database"

if ($hasPsql -and (Test-Path $dbDir)) {
    $resp = Read-Host "Crear/actualizar la base de datos PostgreSQL ahora? (S/N) [S]"
    if (-not ($resp -match '^[Nn]')) {
        Write-Step "Configurando base de datos"

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
            $existe = & psql -h $dbHost -p $dbPort -U $dbUser -tAc "SELECT 1 FROM pg_database WHERE datname='$dbName'" postgres 2>&1
            if ($existe -notmatch "1") {
                & psql -h $dbHost -p $dbPort -U $dbUser -c "CREATE DATABASE $dbName;" postgres 2>&1 | Out-Null
                Write-Ok "Base de datos '$dbName' creada"
            } else {
                Write-Ok "La base de datos '$dbName' ya existe"
            }

            Get-ChildItem -Path $dbDir -Filter "*.sql" | Sort-Object Name | ForEach-Object {
                & psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -f $_.FullName 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "Aplicado: $($_.Name)"
                } else {
                    Write-Warn2 "Hubo errores al aplicar $($_.Name) (revisa arriba)"
                }
            }

            $propsPath = Join-Path $backendDir "src\main\resources\application.properties"
            if (Test-Path $propsPath) {
                $jdbcUrl = "jdbc:postgresql://${dbHost}:${dbPort}/${dbName}"
                (Get-Content $propsPath -Raw) `
                    -replace 'spring\.datasource\.url=.*', "spring.datasource.url=$jdbcUrl" `
                    -replace 'spring\.datasource\.username=.*', "spring.datasource.username=$dbUser" `
                    -replace 'spring\.datasource\.password=.*', "spring.datasource.password=$dbPass" |
                    Set-Content $propsPath -Encoding UTF8
                Write-Ok "application.properties actualizado con las credenciales ingresadas"
            }
        } catch {
            Write-Warn2 "Error al conectar con PostgreSQL: $_"
        } finally {
            Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
            $ErrorActionPreference = $prevEAP
        }
    }
} elseif (-not $hasPsql) {
    Write-Warn2 "Sin 'psql' no se configura la base de datos automaticamente. Corre a mano los .sql de database\ cuando instales PostgreSQL."
}

# ---------------------------------------------------------------------------
# 5. Resumen final
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Proyecto restaurado" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
if ($faltantes.Count -gt 0) {
    Write-Host " Instala lo que falto arriba antes de correr todo el proyecto."
}
Write-Host " Para iniciar:"
Write-Host "   cd backend  ; mvn spring-boot:run"
Write-Host "   cd frontend ; npm start"
Write-Host ""
'@

    $writer.Write($cuerpoRestauracion)
} finally {
    $writer.Close()
    $writer.Dispose()
}

Write-Ok "restaurar_proyecto_actual.ps1 generado"

# ---------------------------------------------------------------------------
# 5. Generar el .bat lanzador de la restauracion
# ---------------------------------------------------------------------------
$batRestaurar = @'
@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Restaurar proyecto (snapshot generado el FECHA_CAPTURA)
echo  Sistema de Activos Fijos y Presupuestos - Grupo 7
echo =====================================================
echo.
echo Este script reconstruye el proyecto TAL COMO ESTABA en el
echo momento en que se genero este paquete, en esta misma carpeta.
echo.

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restaurar_proyecto_actual.ps1"

echo.
echo Proceso finalizado. Revisa los mensajes de arriba.
pause
'@
$batRestaurar = $batRestaurar.Replace("FECHA_CAPTURA", $fecha)
Write-FileNoBom (Join-Path $root "restaurar_proyecto_actual.bat") $batRestaurar
Write-Ok "restaurar_proyecto_actual.bat generado"

# ---------------------------------------------------------------------------
# 6. REQUISITOS.txt legible
# ---------------------------------------------------------------------------
$requisitosTxt = @"
REQUISITOS PARA CORRER ESTE PROYECTO
Sistema de Activos Fijos y Presupuestos - Grupo 7 (UAGRM - FICCT)
Snapshot generado: $fecha

Software necesario (instalar antes de correr restaurar_proyecto_actual.bat
o, al menos, antes de iniciar backend/frontend):

1) Java 17 o superior (JDK)
   Descarga: https://adoptium.net/
   Alternativa: winget install EclipseAdoptium.Temurin.17.JDK

2) Maven 3.8 o superior
   Descarga: https://maven.apache.org/download.cgi
   Alternativa: winget install Apache.Maven

3) Node.js 18 o superior (incluye npm)
   Descarga: https://nodejs.org/
   Alternativa: winget install OpenJS.NodeJS.LTS

4) PostgreSQL 14 o superior (con el cliente psql en el PATH)
   Descarga: https://www.postgresql.org/download/windows/
   Importante: durante la instalacion, agregar la carpeta "bin" de
   PostgreSQL al PATH del sistema para que el comando 'psql' funcione.

5) Git (opcional, solo si vas a versionar el proyecto)
   Descarga: https://git-scm.com/download/win

--------------------------------------------------------
Herramientas detectadas en el equipo donde se genero este
paquete (referencia, no necesariamente las que tenes vos):

  Java : $verJava
  Maven: $verMvn
  Node : $verNode
  npm  : $verNpm
  psql : $verPsql
  Git  : $verGit

--------------------------------------------------------
Como usar este paquete en una maquina nueva:

  1) Copia restaurar_proyecto_actual.bat y restaurar_proyecto_actual.ps1
     a una carpeta vacia.
  2) Doble clic en restaurar_proyecto_actual.bat
  3) El script te va a avisar que falta instalar (si algo falta),
     va a reconstruir backend\, frontend\ y database\ tal como estaban
     al momento de la captura, y te va a ofrecer instalar dependencias
     del frontend y configurar la base de datos.
  4) Al final: cd backend ; mvn spring-boot:run
              cd frontend ; npm start
"@
Write-FileNoBom (Join-Path $root "REQUISITOS.txt") $requisitosTxt
Write-Ok "REQUISITOS.txt generado"

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Captura completa"  -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Se generaron 3 archivos en esta carpeta:"
Write-Host "   - restaurar_proyecto_actual.bat"
Write-Host "   - restaurar_proyecto_actual.ps1  (contiene TODO el proyecto embebido)"
Write-Host "   - REQUISITOS.txt"
Write-Host ""
Write-Host " Copia esos 2 archivos .bat/.ps1 a cualquier carpeta vacia"
Write-Host " (en esta PC o en otra) y corre el .bat para reconstruir el"
Write-Host " proyecto exactamente como esta ahora mismo, sin internet."
Write-Host ""
