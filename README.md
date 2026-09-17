# Sistema de Activos Fijos y Presupuestos - Grupo 7 (UAGRM - FICCT)

Proyecto generado automaticamente hasta el alcance del **Sprint 1**
(HU-01 Iniciar sesion, HU-02 Registrar activos por categoria, HU-03 Asignar activos a responsables y ubicaciones).

## Estructura

- `backend/`  -> Spring Boot + PostgreSQL + JWT (puerto 8080)
- `frontend/` -> Angular standalone (puerto 4200)
- `database/schema.sql` -> script de creacion de la base de datos

## Como correr el backend

```
cd backend
mvn spring-boot:run
```

(Si no tenes Maven instalado: instalalo desde https://maven.apache.org/download.cgi
o con `choco install maven` / `winget install Apache.Maven`.)

Antes, crear la base de datos ejecutando `database/schema.sql` en PostgreSQL
y ajustar usuario/clave en `backend/src/main/resources/application.properties`.

## Como correr el frontend

```
cd frontend
npm install
npm start
```

Luego abrir http://localhost:4200
