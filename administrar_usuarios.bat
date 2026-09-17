@echo off
setlocal
chcp 65001 >nul

echo =================================================================
echo  Administrar usuarios - Sistema de Activos Fijos y Presupuestos
echo =================================================================
echo.
echo IMPORTANTE: coloca este .bat (junto con administrar_usuarios.ps1)
echo en la carpeta raiz del proyecto, la misma carpeta donde estan
echo backend\ y frontend\.
echo.
echo Este script NO toca el codigo del proyecto: solo administra los
echo usuarios guardados en la base de datos PostgreSQL.
echo.

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0administrar_usuarios.ps1"

echo.
pause