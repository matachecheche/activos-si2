@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Llenar datos ficticios + mejorar interfaz
echo  Sistema de Activos Fijos y Presupuestos - Grupo 7
echo =====================================================
echo.
echo IMPORTANTE: coloca este .bat (junto con llenar_datos_prueba.ps1)
echo en la misma carpeta donde estan backend\, frontend\ y database\
echo de tu proyecto ya generado.
echo.
pause

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0llenar_datos_prueba.ps1"

echo.
echo Proceso finalizado. Revisa los mensajes de arriba.
echo Si el backend ya estaba corriendo, reinicialo para que
echo tome los nuevos endpoints de categorias/ubicaciones.
echo.
pause
