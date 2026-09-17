@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Restaurar proyecto (snapshot generado el 2026-09-17 13:59)
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