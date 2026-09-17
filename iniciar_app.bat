@echo off
setlocal
chcp 65001 >nul

echo =====================================================
echo  Iniciar app - Sistema de Activos Fijos y Presupuestos
echo =====================================================
echo.

cd /d "%~dp0"

set "JAVA25_HOME=%USERPROFILE%\.jdk\jdk-25.0.2"
if not exist "%JAVA25_HOME%\bin\java.exe" (
    echo [ERROR] No se encontro JDK 25 en "%JAVA25_HOME%".
    echo         Instala JDK 25 o ajusta JAVA25_HOME en este archivo.
    pause
    exit /b 1
)
set "JAVA_HOME=%JAVA25_HOME%"
set "PATH=%JAVA_HOME%\bin;%PATH%"

for /f "tokens=3" %%v in ('java -version 2^>^&1 ^| findstr /i "version"') do set "JAVA_VERSION=%%v"
echo Java seleccionado: %JAVA_HOME%
echo Version: %JAVA_VERSION%

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
start "Backend - activos-backend" cmd /k "set "JAVA_HOME=%JAVA_HOME%" && set "PATH=%JAVA_HOME%\bin;%PATH%" && cd /d "%~dp0backend" && mvn spring-boot:run"

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
