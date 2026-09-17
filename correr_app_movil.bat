@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Correr / generar APK - App movil Activos Fijos
echo =====================================================
echo.
echo IMPORTANTE: coloca este .bat (junto con correr_app_movil.ps1)
echo en la misma carpeta donde esta mobile\ (junto a backend\ y
echo frontend\ de tu proyecto).
echo.

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0correr_app_movil.ps1"
