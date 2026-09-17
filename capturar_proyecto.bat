@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Capturar snapshot del proyecto ACTUAL
echo  Sistema de Activos Fijos y Presupuestos - Grupo 7
echo =====================================================
echo.
echo Esto va a leer backend\, frontend\ y database\ tal como
echo estan AHORA MISMO (con tus cambios) y generar un paquete
echo (restaurar_proyecto_actual.bat + .ps1) capaz de reconstruir
echo el proyecto identico en cualquier PC, mas un REQUISITOS.txt
echo con todo lo que hay que instalar.
echo.
echo IMPORTANTE: coloca este .bat (junto con capturar_proyecto.ps1)
echo en la misma carpeta donde estan backend\, frontend\ y database\.
echo No incluye node_modules ni target (se regeneran solos).
echo.
pause

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0capturar_proyecto.ps1"

echo.
pause
