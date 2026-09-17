@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Generar app movil (Flutter)
echo  Sistema de Activos Fijos y Presupuestos - Grupo 7
echo =====================================================
echo.
echo IMPORTANTE: coloca este .bat (junto con crear_app_movil.ps1)
echo en la misma carpeta donde estan backend\, frontend\ y database\
echo de tu proyecto.
echo.
echo Si todavia no tenes el SDK de Flutter instalado, este script
echo te va a dar los pasos exactos para instalarlo y despues vas
echo a tener que volver a correr este mismo .bat.
echo.
pause

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0crear_app_movil.ps1"

echo.
pause
