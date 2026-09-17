@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Arreglo de problemas - Sistema de Activos Fijos
echo  y Presupuestos - Grupo 7 (UAGRM - FICCT)
echo  - Limpia el build del backend (error de Lombok)
echo  - Siembra/desbloquea 4 usuarios de prueba (1 por rol)
echo  - Limpia la pantalla inicial de Angular
echo  - Agrega los usuarios de prueba sugeridos al login
echo =====================================================
echo.
echo IMPORTANTE: coloca este .bat (junto con fix.ps1) en la
echo misma carpeta donde estan las carpetas backend\, frontend\
echo y database\ de tu proyecto ya generado.
echo.
pause

cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro PowerShell en este equipo.
    echo         PowerShell viene incluido en Windows 10/11 por defecto.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix.ps1"

echo.
echo Proceso finalizado. Revisa los mensajes de arriba.
echo Si dice "AVISO" en amarillo, atiende ese paso manualmente
echo (por ejemplo, correr el .sql a mano si no tienes psql en el PATH).
echo Este .bat se puede correr varias veces sin problema.
echo.
pause
