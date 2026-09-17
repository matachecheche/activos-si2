#
# correr_app_movil.ps1
# Menu para: 1) correr la app movil en modo desarrollo, o
#            2) generar un APK e instalarlo/abrirlo automaticamente
#            en un celular conectado por USB.
#

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Write-Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    AVISO: $msg" -ForegroundColor Yellow }

function Invoke-Tolerante($bloque) {
    # Ejecuta comandos externos (flutter/adb) sin que PowerShell trate su
    # salida normal por stderr como un error fatal.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $bloque } finally { $ErrorActionPreference = $prevEAP }
}

$mobileDir = Join-Path $root "mobile"

# ---------------------------------------------------------------------------
# Verificaciones previas
# ---------------------------------------------------------------------------
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Warn2 "No se encontro 'flutter' en el PATH. Instalalo primero (ver crear_app_movil.bat)."
    Read-Host "Presiona Enter para salir"
    exit 1
}

if (-not (Test-Path (Join-Path $mobileDir "pubspec.yaml"))) {
    Write-Warn2 "No se encontro mobile\pubspec.yaml. Corre primero crear_app_movil.bat."
    Read-Host "Presiona Enter para salir"
    exit 1
}

$hasAdb = $null -ne (Get-Command adb -ErrorAction SilentlyContinue)

# Intenta leer el applicationId real del proyecto Android generado
$appId = "com.uagrm.activos.activos_fijos_app"
$gradlePath = Join-Path $mobileDir "android\app\build.gradle"
$gradleKtsPath = Join-Path $mobileDir "android\app\build.gradle.kts"
$gradleFile = if (Test-Path $gradlePath) { $gradlePath } elseif (Test-Path $gradleKtsPath) { $gradleKtsPath } else { $null }
if ($gradleFile) {
    $match = Select-String -Path $gradleFile -Pattern 'applicationId\s*=?\s*"([^"]+)"' | Select-Object -First 1
    if ($match) { $appId = $match.Matches[0].Groups[1].Value }
}

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " App movil - Sistema de Activos Fijos y Presupuestos" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Recorda: el backend (mvn spring-boot:run) tiene que estar"
Write-Host " corriendo y accesible desde donde pruebes la app, y la URL"
Write-Host " en mobile\lib\config\api_config.dart tiene que apuntar ahi."
Write-Host ""
Write-Host " 1) Correr la app en modo desarrollo (emulador o celular por USB)"
Write-Host " 2) Generar APK e instalarlo/abrirlo en un celular conectado"
Write-Host " 3) Salir"
Write-Host ""
$opcion = Read-Host "Elegi una opcion (1/2/3)"

Push-Location $mobileDir

switch ($opcion) {

    "1" {
        Write-Step "Dispositivos disponibles"
        Invoke-Tolerante { flutter devices 2>&1 | Write-Host }
        Write-Host ""
        Write-Host "Si hay mas de un dispositivo, 'flutter run' te va a preguntar cual usar."
        Write-Host "Presiona Ctrl+C en esta ventana para detener la app cuando quieras."
        Write-Host ""
        Read-Host "Presiona Enter para iniciar 'flutter run'"
        Invoke-Tolerante { flutter run 2>&1 | Write-Host }
    }

    "2" {
        Write-Step "Generando APK (release)"
        Write-Host "    Esto puede tardar varios minutos la primera vez..."
        Invoke-Tolerante { flutter build apk --release 2>&1 | Write-Host }

        $apkPath = Join-Path $mobileDir "build\app\outputs\flutter-apk\app-release.apk"
        if (-not (Test-Path $apkPath)) {
            Write-Warn2 "No se genero el APK esperado en $apkPath. Revisa los mensajes de arriba."
            Pop-Location
            Read-Host "Presiona Enter para salir"
            exit 1
        }

        Write-Ok "APK generado: $apkPath"

        if (-not $hasAdb) {
            Write-Warn2 "No se encontro 'adb' en el PATH (viene con el SDK de Android / platform-tools)."
            Write-Warn2 "Copia el APK a tu celular manualmente e instalalo desde el explorador de archivos."
        } else {
            Write-Step "Buscando un celular conectado por USB (con depuracion USB activada)"
            $dispositivos = Invoke-Tolerante { adb devices 2>&1 }
            $lineasDispositivo = $dispositivos | Select-String "\bdevice\b" | Where-Object { $_ -notmatch "List of devices" }

            if (-not $lineasDispositivo) {
                Write-Warn2 "No se detecto ningun celular por USB con depuracion habilitada."
                Write-Warn2 "Activa 'Opciones de desarrollador' > 'Depuracion USB' en tu Android, conecta"
                Write-Warn2 "el cable, acepta el permiso que aparece en el celular, y volve a correr este script."
                Write-Warn2 "El APK ya quedo generado en: $apkPath (podes copiarlo a mano si preferis)."
            } else {
                $resp = Read-Host "Se detecto un celular conectado. Instalar y abrir la app ahora? (S/N) [S]"
                if (-not ($resp -match '^[Nn]')) {
                    Write-Step "Instalando APK"
                    Invoke-Tolerante { adb install -r $apkPath 2>&1 | Write-Host }
                    Write-Ok "APK instalado"

                    Write-Step "Abriendo la app en el celular"
                    Invoke-Tolerante { adb shell monkey -p $appId -c android.intent.category.LAUNCHER 1 2>&1 | Write-Host }
                    Write-Ok "App abierta (si no se abrio sola, buscala en el celular como 'activos_fijos_app')"
                }
            }
        }
    }

    default {
        Write-Host "Saliendo."
    }
}

Pop-Location

Write-Host ""
Read-Host "Presiona Enter para cerrar"
