@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Generador del proyecto: Sistema de Activos Fijos
echo  y Presupuestos - Grupo 7 (UAGRM - FICCT)
echo  Alcance: hasta el Sprint 1 (HU-01, HU-02, HU-03)
echo =====================================================
echo.

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    echo         PowerShell viene incluido en Windows 10/11 por defecto.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

echo.
echo Proceso finalizado. Revisa los mensajes de arriba.
echo Si algo salio en color amarillo ("AVISO"), instala la
echo herramienta faltante (Java, Node/npm o Git) y vuelve
echo a ejecutar este .bat: puede correrse varias veces sin
echo romper lo que ya se genero.
echo.
pause
