#
# administrar_usuarios.ps1
# Administracion de usuarios del "Sistema de Activos Fijos y Presupuestos".
#
# - NO modifica ningun archivo del proyecto (backend, frontend, movil).
# - Lee los datos de conexion desde backend\src\main\resources.
# - Solo ejecuta SELECT/INSERT/UPDATE/DELETE sobre la tabla de usuarios.
# - Contrasenas con bcrypt (mismo algoritmo que Spring Security) usando
#   la extension pgcrypto de PostgreSQL.
# - Nunca deja al sistema sin su ultimo usuario ADMIN.
#
# Si la autodeteccion falla, puedes fijar aqui los datos a mano:
 $PgHost       = ""      # ej: localhost
 $PgPort       = ""      # ej: 5432
 $PgDatabase   = ""      # ej: activos_fijos
 $PgUser       = ""      # ej: postgres
 $PgPassword   = ""
 $TablaForzada = ""      # ej: usuarios
#

 $ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
 $env:PGCLIENTENCODING = 'UTF8'
 $root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Write-Step($msg)  { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    AVISO: $msg" -ForegroundColor Yellow }
function Write-Err2($msg)  { Write-Host "    ERROR: $msg" -ForegroundColor Red }

function SqlLit([string]$s) {
    if ($null -eq $s) { return 'NULL' }
    return "'" + $s.Replace("'", "''") + "'"
}

function Read-Default([string]$prompt, [string]$default) {
    $v = Read-Host $prompt
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v.Trim()
}

function Invoke-PsqlSql {
    param([string]$sql, [switch]$Tuples)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $env:PGPASSWORD = $script:PgPassword
        $a = @('-h', $script:PgHost, '-p', $script:PgPort, '-U', $script:PgUser,
               '-d', $script:PgDatabase, '-v', 'ON_ERROR_STOP=1', '-X', '-P', 'pager=off')
        if ($Tuples) { $a += @('-t', '-A') }
        $a += @('-c', $sql)
        $out = & $script:PsqlExe @a 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    $text = ($out | ForEach-Object { "$_" }) -join "`n"
    if ($code -ne 0) { throw $text }
    return $text
}

function Get-Scalar([string]$sql) {
    $t = Invoke-PsqlSql $sql -Tuples
    if ([string]::IsNullOrWhiteSpace($t)) { return $null }
    return (($t -split "\r?\n")[0]).Trim()
}

function Resolve-Placeholder([string]$v) {
    if ($null -eq $v) { return $null }
    $v = $v.Trim()
    $v = [regex]::Replace($v, '\$\{[^}:]+:([^}]*)\}', '$1')
    $v = [regex]::Replace($v, '\$\{[^}]*\}', '')
    return $v.Trim()
}

# ---------------------------------------------------------------
# 1. Localizar psql
# ---------------------------------------------------------------
Write-Step "Buscando psql (cliente de PostgreSQL)"
 $script:PsqlExe = $null
if (Get-Command psql -ErrorAction SilentlyContinue) { $script:PsqlExe = "psql" }
if (-not $script:PsqlExe) {
    $script:PsqlExe = Get-Item "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue |
        Sort-Object { try { [int]($_.Directory.Name) } catch { 0 } } -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $script:PsqlExe) {
    Write-Err2 "No se encontro 'psql'. Instala PostgreSQL o agregalo al PATH."
    Read-Host "Presiona Enter para salir"; exit 1
}
Write-Ok "psql: $($script:PsqlExe)"

# ---------------------------------------------------------------
# 2. Leer conexion desde la configuracion del backend
# ---------------------------------------------------------------
Write-Step "Leyendo configuracion de la base de datos desde backend\src\main\resources"
 $resDir = Join-Path $root 'backend\src\main\resources'
 $rawConf = $null
foreach ($f in @('application.properties','application.yml','application.yaml')) {
    $p = Join-Path $resDir $f
    if (Test-Path $p) { $rawConf = Get-Content $p -Raw; Write-Ok "Usando: $p"; break }
}
if ($rawConf) {
    if (-not $script:PgHost) {
        $m = [regex]::Match($rawConf, 'jdbc:postgresql://([^:/\s"]+)(?::(\d+))?/([^?\s"]+)')
        if ($m.Success) {
            $script:PgHost = $m.Groups[1].Value
            if ($m.Groups[2].Success) { $script:PgPort = $m.Groups[2].Value }
            $script:PgDatabase = $m.Groups[3].Value
        }
    }
    if (-not $script:PgUser) {
        $m = [regex]::Match($rawConf, '(?m)^\s*spring\.datasource\.username\s*[:=]\s*(.+?)\s*$')
        if (-not $m.Success) { $m = [regex]::Match($rawConf, '(?m)^\s+username\s*:\s*(.+?)\s*$') }
        if ($m.Success) { $script:PgUser = Resolve-Placeholder $m.Groups[1].Value }
    }
    if (-not $script:PgPassword) {
        $m = [regex]::Match($rawConf, '(?m)^\s*spring\.datasource\.password\s*[:=]\s*(.+?)\s*$')
        if (-not $m.Success) { $m = [regex]::Match($rawConf, '(?m)^\s+password\s*:\s*(.+?)\s*$') }
        if ($m.Success) { $script:PgPassword = Resolve-Placeholder $m.Groups[1].Value }
    }
} else {
    Write-Warn2 "No se encontro backend\src\main\resources\application.properties|.yml"
}

if (-not $script:PgHost)   { $script:PgHost = 'localhost' }
if (-not $script:PgPort)   { $script:PgPort = '5432' }
if (-not $script:PgUser)   { $script:PgUser = 'postgres' }

Write-Host ""
Write-Host "  Conexion a PostgreSQL (Enter = aceptar el valor entre corchetes)" -ForegroundColor White
 $script:PgHost     = Read-Default "    Servidor [$($script:PgHost)]: " $script:PgHost
 $script:PgPort     = Read-Default "    Puerto   [$($script:PgPort)]: " $script:PgPort
 $script:PgUser     = Read-Default "    Usuario  [$($script:PgUser)]: " $script:PgUser
 $script:PgDatabase = Read-Default "    Base de datos [$($script:PgDatabase)]: " $script:PgDatabase
if (-not $script:PgDatabase) { Write-Err2 "Se necesita el nombre de la base de datos."; Read-Host "Enter para salir"; exit 1 }
if (-not $script:PgPassword) { $script:PgPassword = Read-Host "    Contrasena (Enter si no tiene)" }

try {
    $db = Get-Scalar "SELECT current_database();"
    Write-Ok "Conexion establecida con '$db'"
} catch {
    Write-Err2 "No se pudo conectar: $_"
    Read-Host "Presiona Enter para salir"; exit 1
}

# ---------------------------------------------------------------
# 3. Detectar tabla y columnas de usuarios
# ---------------------------------------------------------------
Write-Step "Detectando la tabla de usuarios"
 $script:Tabla = $TablaForzada
if (-not $script:Tabla) {
    $script:Tabla = Get-Scalar "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE 'usuario%' OR table_name ILIKE '%users%' OR table_name='user') ORDER BY CASE WHEN table_name ILIKE 'usuarios' THEN 0 WHEN table_name ILIKE 'usuario%' THEN 1 ELSE 2 END LIMIT 1;"
}
if (-not $script:Tabla) {
    $script:Tabla = Read-Host "  No se detecto automaticamente. Escribe el nombre de la tabla de usuarios"
}
if (-not $script:Tabla) { Write-Err2 "Sin tabla no se puede continuar."; Read-Host "Enter"; exit 1 }
Write-Ok "Tabla de usuarios: $($script:Tabla)"

 $script:Cols = New-Object System.Collections.Generic.List[object]
 $rawCols = Invoke-PsqlSql "SELECT column_name||'|'||data_type||'|'||is_nullable||'|'||coalesce(column_default,'-')||'|'||is_identity FROM information_schema.columns WHERE table_schema='public' AND table_name='$($script:Tabla)' ORDER BY ordinal_position;" -Tuples
foreach ($line in ($rawCols -split "\r?\n")) {
    $line = $line.Trim()
    if (-not $line) { continue }
    $p = $line -split '\|', 5
    if ($p.Count -lt 5) { continue }
    $script:Cols.Add([pscustomobject]@{ Name=$p[0]; Type=$p[1]; Nullable=$p[2]; Default=$p[3]; Identity=$p[4] })
}

function Find-Col([string[]]$patterns) {
    foreach ($pt in $patterns) {
        foreach ($c in $script:Cols) {
            if ($c.Name -match '^[A-Za-z_][A-Za-z0-9_]*$' -and $c.Name -match $pt) { return $c.Name }
        }
    }
    return $null
}
 $script:ColId      = Find-Col @('^id$','_id$','^id_')
 $script:ColEmail   = Find-Col @('correo','email','mail')
 $script:ColNombre  = Find-Col @('nombre','^name','full_?name')
 $script:ColPass    = Find-Col @('password','contrasen','pass')
 $script:ColRol     = Find-Col @('^rol$','rol_','role','perfil')
 $script:ColIntentos= Find-Col @('intento','fallid','failed')
 $script:ColBloqueo = Find-Col @('bloquea','bloquead','bloqueo','locked','lock_')
 $script:ColActivo  = Find-Col @('^activo$','enabled','habilitado','^estado$','status')

if (-not $script:ColEmail -or -not $script:ColPass) {
    Write-Err2 "No se identificaron las columnas de correo/password en '$($script:Tabla)'. Columnas: $(($script:Cols.Name) -join ', ')"
    Read-Host "Presiona Enter para salir"; exit 1
}

Write-Host ""
Write-Host "  Estructura detectada:" -ForegroundColor White
Write-Host "    id:               $($script:ColId)"
Write-Host "    correo:           $($script:ColEmail)"
Write-Host "    nombre:           $($script:ColNombre)"
Write-Host "    password:         $($script:ColPass)"
Write-Host "    rol:              $($script:ColRol)"
Write-Host "    intentos fallidos:$($script:ColIntentos)"
Write-Host "    bloqueo:          $($script:ColBloqueo)"
Write-Host "    activo/estado:    $($script:ColActivo)"
Write-Host "    (Solo se leen/escriben datos de la tabla '$($script:Tabla)')"

# Formato de contrasenas existentes
 $muestra = Get-Scalar "SELECT $($script:ColPass) FROM $($script:Tabla) WHERE $($script:ColPass) IS NOT NULL AND $($script:ColPass) <> '' LIMIT 1;"
 $script:UsaBcrypt = $true
 $script:PrefijoHash = ''
if ($muestra) {
    if ($muestra -match '^\{bcrypt\}') { $script:PrefijoHash = '{bcrypt}' }
    elseif ($muestra -match '^\$2[aby]\$') { }
    else {
        $script:UsaBcrypt = $false
        Write-Warn2 "Las contrasenas existentes NO parecen bcrypt. Se guardaran en el mismo formato que ya usa tu sistema."
    }
} else {
    Write-Warn2 "Tabla vacia: se usara bcrypt (estandar de Spring Security)."
}

function Ensure-Pgcrypto {
    if (-not $script:UsaBcrypt) { return $true }
    try {
        $v = Get-Scalar "SELECT crypt('probe', gen_salt('bf', 4));"
        if ($v -match '^\$2') { return $true }
    } catch {
        try {
            Invoke-PsqlSql "CREATE EXTENSION IF NOT EXISTS pgcrypto;" | Out-Null
            $v = Get-Scalar "SELECT crypt('probe', gen_salt('bf', 4));"
            if ($v -match '^\$2') { Write-Ok "Extension pgcrypto habilitada."; return $true }
        } catch {
            Write-Warn2 "No se pudo habilitar pgcrypto: $_"
            Write-Warn2 "Ejecuta una vez como administrador de la BD: CREATE EXTENSION pgcrypto;"
        }
    }
    return $false
}

function New-PasswordSql([string]$plain) {
    if ($script:UsaBcrypt) {
        $pref = ''
        if ($script:PrefijoHash) { $pref = (SqlLit $script:PrefijoHash) + ' || ' }
        return "($pref" + "crypt($(SqlLit $plain), gen_salt('bf', 10)))"
    }
    return (SqlLit $plain)
}

function Reset-BloqueoExpr {
    $c = $script:Cols | Where-Object { $_.Name -eq $script:ColBloqueo } | Select-Object -First 1
    if ($c -and $c.Type -eq 'boolean') { return 'false' }
    return 'NULL'
}

# ---------------------------------------------------------------
# 4. Acciones
# ---------------------------------------------------------------
function Show-Usuarios {
    Write-Step "Listado de usuarios (tabla: $($script:Tabla))"
    $cols = @()
    foreach ($c in @($script:ColId, $script:ColEmail, $script:ColNombre, $script:ColRol, $script:ColActivo, $script:ColIntentos, $script:ColBloqueo)) {
        if ($c -and ($cols -notcontains $c)) { $cols += $c }
    }
    foreach ($c in $script:Cols) {
        if ($cols.Count -ge 10) { break }
        if ($cols -notcontains $c.Name -and $c.Name -ne $script:ColPass) { $cols += $c.Name }
    }
    try { Invoke-PsqlSql "SELECT $($cols -join ', ') FROM $($script:Tabla) ORDER BY $($script:ColId);" | Write-Host }
    catch { Write-Err2 "No se pudo listar: $_" }
}

function Select-UsuarioId {
    Show-Usuarios
    $id = Read-Host "  ID del usuario (Enter para cancelar)"
    if (-not $id) { return $null }
    if ($id -notmatch '^\d+$') { Write-Warn2 "ID invalido."; return $null }
    $existe = Get-Scalar "SELECT count(*) FROM $($script:Tabla) WHERE $($script:ColId)=$id;"
    if ($existe -ne '1') { Write-Warn2 "No existe un usuario con ese ID."; return $null }
    return [int]$id
}

function Test-UltimoAdmin([int]$id) {
    if (-not $script:ColRol) { return $false }
    $esAdmin = Get-Scalar "SELECT count(*) FROM $($script:Tabla) WHERE $($script:ColId)=$id AND lower($($script:ColRol)) LIKE '%admin%';"
    if ($esAdmin -ne '1') { return $false }
    $otros = Get-Scalar "SELECT count(*) FROM $($script:Tabla) WHERE lower($($script:ColRol)) LIKE '%admin%' AND $($script:ColId)<>$id;"
    return ([int]$otros -eq 0)
}

function New-Usuario {
    Write-Step "Crear usuario"
    if (-not (Ensure-Pgcrypto)) { Write-Err2 "No se puede generar el hash de contrasena (ver mensajes)."; return }

    $correo = (Read-Host "  Correo institucional").Trim()
    if ($correo -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { Write-Warn2 "Correo invalido."; return }
    $dup = Get-Scalar "SELECT count(*) FROM $($script:Tabla) WHERE lower($($script:ColEmail))=lower($(SqlLit $correo));"
    if ($dup -ne '0') { Write-Warn2 "Ya existe un usuario con ese correo."; return }

    $nombre = (Read-Host "  Nombre completo").Trim()
    if (-not $nombre) { Write-Warn2 "El nombre no puede estar vacio."; return }

    $p1 = Read-Host "  Contrasena (minimo 6 caracteres)"
    if ($p1.Length -lt 6) { Write-Warn2 "Contrasena demasiado corta."; return }
    if ($p1 -cne (Read-Host "  Repite la contrasena")) { Write-Warn2 "Las contrasenas no coinciden."; return }

    $rol = $null
    if ($script:ColRol) {
        $roles = @((Invoke-PsqlSql "SELECT DISTINCT $($script:ColRol) FROM $($script:Tabla) WHERE $($script:ColRol) IS NOT NULL ORDER BY 1;" -Tuples) -split "\r?\n" | Where-Object { $_ })
        Write-Host "  Roles existentes:"
        $i = 1
        foreach ($r in $roles) { Write-Host "    $i) $r"; $i++ }
        $op = Read-Host "  Elige rol (numero) o escribe uno (ej. ADMIN / USER)"
        if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $roles.Count) { $rol = $roles[[int]$op - 1] }
        elseif ($op) { $rol = $op.Trim().ToUpper() }
        if (-not $rol) { Write-Warn2 "Cancelado."; return }
    }

    $extraCols = @(); $extraVals = @()
    foreach ($c in $script:Cols) {
        if ($c.Name -in @($script:ColId, $script:ColEmail, $script:ColNombre, $script:ColPass, $script:ColRol)) { continue }
        if ($c.Identity -eq 'YES' -or $c.Default -ne '-' -or $c.Nullable -eq 'YES') { continue }
        if ($c.Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { continue }
        $val = Read-Host "  Columna obligatoria '$($c.Name)' ($($c.Type)) - valor (Enter = cancelar)"
        if ([string]::IsNullOrWhiteSpace($val)) { Write-Warn2 "Cancelado."; return }
        $extraCols += $c.Name
        if ($c.Type -in @('integer','bigint','smallint','numeric','decimal','real','double precision')) { $extraVals += $val }
        elseif ($c.Type -eq 'boolean') { $extraVals += $(if ($val -match '^(s|si|true|1)$') { 'true' } else { 'false' }) }
        else { $extraVals += (SqlLit $val) }
    }

    $ci = New-Object System.Collections.Generic.List[string]
    $cv = New-Object System.Collections.Generic.List[string]
    $ci.Add($script:ColEmail); $cv.Add((SqlLit $correo))
    if ($script:ColNombre) { $ci.Add($script:ColNombre); $cv.Add((SqlLit $nombre)) }
    $ci.Add($script:ColPass);  $cv.Add((New-PasswordSql $p1))
    if ($rol) { $ci.Add($script:ColRol); $cv.Add((SqlLit $rol)) }
    for ($i = 0; $i -lt $extraCols.Count; $i++) { $ci.Add($extraCols[$i]); $cv.Add($extraVals[$i]) }

    try {
        Invoke-PsqlSql "INSERT INTO $($script:Tabla) ($($ci -join ', ')) VALUES ($($cv -join ', '));" | Out-Null
        Write-Ok "Usuario creado: $correo (rol: $rol). Ya puede iniciar sesion."
    } catch { Write-Err2 "No se pudo crear el usuario: $_" }
}

function Remove-Usuario {
    Write-Step "Eliminar usuario"
    $id = Select-UsuarioId
    if (-not $id) { return }
    if (Test-UltimoAdmin $id) { Write-Err2 "Bloqueado: es el ULTIMO usuario ADMIN del sistema."; return }
    Write-Warn2 "Sugerencia: si prefieres conservar el historial, usa la opcion 6 (desactivar)."
    if ((Read-Host "  Confirma escribiendo ELIMINAR") -cne 'ELIMINAR') { Write-Warn2 "Cancelado."; return }
    Invoke-PsqlSql "DELETE FROM $($script:Tabla) WHERE $($script:ColId)=$id;" | Out-Null
    Write-Ok "Usuario $id eliminado."
}

function Reset-Password {
    Write-Step "Cambiar contrasena"
    $id = Select-UsuarioId
    if (-not $id) { return }
    if (-not (Ensure-Pgcrypto)) { Write-Err2 "No se puede generar el hash (ver mensajes)."; return }
    $p1 = Read-Host "  Nueva contrasena (minimo 6)"
    if ($p1.Length -lt 6) { Write-Warn2 "Demasiado corta."; return }
    if ($p1 -cne (Read-Host "  Repitela")) { Write-Warn2 "No coinciden."; return }
    $sets = "$($script:ColPass) = $(New-PasswordSql $p1)"
    if ($script:ColIntentos) { $sets += ", $($script:ColIntentos) = 0" }
    if ($script:ColBloqueo)  { $sets += ", $($script:ColBloqueo) = $(Reset-BloqueoExpr)" }
    Invoke-PsqlSql "UPDATE $($script:Tabla) SET $sets WHERE $($script:ColId)=$id;" | Out-Null
    Write-Ok "Contrasena actualizada (y cuenta desbloqueada si estaba bloqueada)."
}

function Set-Rol {
    Write-Step "Cambiar rol"
    if (-not $script:ColRol) { Write-Warn2 "La tabla no tiene columna de rol."; return }
    $id = Select-UsuarioId
    if (-not $id) { return }
    $roles = @((Invoke-PsqlSql "SELECT DISTINCT $($script:ColRol) FROM $($script:Tabla) WHERE $($script:ColRol) IS NOT NULL ORDER BY 1;" -Tuples) -split "\r?\n" | Where-Object { $_ })
    Write-Host "  Roles existentes:"
    $i = 1
    foreach ($r in $roles) { Write-Host "    $i) $r"; $i++ }
    $op = Read-Host "  Nuevo rol (numero o texto)"
    $rol = $null
    if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $roles.Count) { $rol = $roles[[int]$op - 1] }
    elseif ($op) { $rol = $op.Trim().ToUpper() }
    if (-not $rol) { Write-Warn2 "Cancelado."; return }
    if (Test-UltimoAdmin $id -and $rol -notmatch 'admin') {
        if ((Read-Host "  ADVERTENCIA: quitarias el ADMIN a uno de los ultimos admins. Continuar? (S/N)") -notmatch '^[sS]') { return }
    }
    Invoke-PsqlSql "UPDATE $($script:Tabla) SET $($script:ColRol)=$(SqlLit $rol) WHERE $($script:ColId)=$id;" | Out-Null
    Write-Ok "Rol actualizado a '$rol'."
}

function Toggle-Activo {
    Write-Step "Activar / Desactivar usuario"
    if (-not $script:ColActivo) { Write-Warn2 "La tabla no tiene columna 'activo'/'estado'."; return }
    $id = Select-UsuarioId
    if (-not $id) { return }
    if (Test-UltimoAdmin $id) { Write-Err2 "Bloqueado: no puedes desactivar al ULTIMO ADMIN."; return }
    $c = $script:Cols | Where-Object { $_.Name -eq $script:ColActivo } | Select-Object -First 1
    if ($c.Type -eq 'boolean') {
        $cur = Get-Scalar "SELECT $($script:ColActivo)::text FROM $($script:Tabla) WHERE $($script:ColId)=$id;"
        $nuevo = $(if ($cur -eq 'true') { 'false' } else { 'true' })
        if ((Read-Host "  Cambiar '$cur' -> '$nuevo'? (S/N)") -notmatch '^[sS]') { Write-Warn2 "Cancelado."; return }
        Invoke-PsqlSql "UPDATE $($script:Tabla) SET $($script:ColActivo)=$nuevo WHERE $($script:ColId)=$id;" | Out-Null
    } else {
        $vals = @((Invoke-PsqlSql "SELECT DISTINCT $($script:ColActivo)::text FROM $($script:Tabla) ORDER BY 1;" -Tuples) -split "\r?\n" | Where-Object { $_ })
        Write-Host "  Valores posibles:"
        $i = 1
        foreach ($v in $vals) { Write-Host "    $i) $v"; $i++ }
        $op = Read-Host "  Nuevo valor (numero o texto)"
        $nuevo = $null
        if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $vals.Count) { $nuevo = $vals[[int]$op - 1] } elseif ($op) { $nuevo = $op.Trim() }
        if (-not $nuevo) { Write-Warn2 "Cancelado."; return }
        Invoke-PsqlSql "UPDATE $($script:Tabla) SET $($script:ColActivo)=$(SqlLit $nuevo) WHERE $($script:ColId)=$id;" | Out-Null
    }
    Write-Ok "Estado actualizado del usuario $id."
}

function Unlock-Usuario {
    Write-Step "Desbloquear cuenta (error 423: cuenta bloqueada)"
    if (-not ($script:ColIntentos -or $script:ColBloqueo)) { Write-Warn2 "La tabla no tiene columnas de bloqueo/intentos."; return }
    $id = Select-UsuarioId
    if (-not $id) { return }
    $sets = @()
    if ($script:ColIntentos) { $sets += "$($script:ColIntentos) = 0" }
    if ($script:ColBloqueo)  { $sets += "$($script:ColBloqueo) = $(Reset-BloqueoExpr)" }
    Invoke-PsqlSql "UPDATE $($script:Tabla) SET $($sets -join ', ') WHERE $($script:ColId)=$id;" | Out-Null
    Write-Ok "Cuenta desbloqueada: el usuario ya puede iniciar sesion."
}

# ---------------------------------------------------------------
# 5. Menu
# ---------------------------------------------------------------
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Administracion de usuarios - Activos Fijos y Presupuestos" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

while ($true) {
    Write-Host ""
    Write-Host " 1) Listar usuarios" -ForegroundColor White
    Write-Host " 2) Crear usuario"
    Write-Host " 3) Eliminar usuario"
    Write-Host " 4) Cambiar contrasena"
    Write-Host " 5) Cambiar rol"
    Write-Host " 6) Activar / Desactivar usuario"
    Write-Host " 7) Desbloquear cuenta"
    Write-Host " 0) Salir"
    $op = Read-Host "Opcion"
    if     ($op -eq '1') { Show-Usuarios }
    elseif ($op -eq '2') { New-Usuario }
    elseif ($op -eq '3') { Remove-Usuario }
    elseif ($op -eq '4') { Reset-Password }
    elseif ($op -eq '5') { Set-Rol }
    elseif ($op -eq '6') { Toggle-Activo }
    elseif ($op -eq '7') { Unlock-Usuario }
    elseif ($op -eq '0') { Write-Host "Saliendo."; break }
    else { Write-Warn2 "Opcion invalida." }
}