@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Iniciar app - Sistema de Activos Fijos y Presupuestos
echo =====================================================
echo.

cd /d "%~dp0"

if not exist "backend\pom.xml" (
    echo [ERROR] No se encontro backend\pom.xml junto a este .bat.
    echo         Coloca este archivo en la carpeta del proyecto ya generado.
    pause
    exit /b 1
)

if not exist "frontend\package.json" (
    echo [ERROR] No se encontro frontend\package.json junto a este .bat.
    echo         Coloca este archivo en la carpeta del proyecto ya generado.
    pause
    exit /b 1
)

where mvn >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro 'mvn' ^(Maven^) en el PATH.
    pause
    exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo [ERROR] No se encontro 'npm' en el PATH.
    pause
    exit /b 1
)

echo Abriendo el backend en una nueva ventana (puerto 8080)...
start "Backend - activos-backend" cmd /k "cd /d "%~dp0backend" && mvn spring-boot:run"

echo Abriendo el frontend en una nueva ventana (puerto 4200)...
start "Frontend - Angular" cmd /k "cd /d "%~dp0frontend" && npm start"

echo.
echo Esperando a que el frontend levante para abrir el navegador...
timeout /t 12 /nobreak >nul

start "" "http://localhost:4200/login"

echo.
echo Listo. Backend en http://localhost:8080  -  Frontend en http://localhost:4200
echo Para detener, cierra las dos ventanas nuevas que se abrieron (o Ctrl+C en cada una).
echo.
pause
