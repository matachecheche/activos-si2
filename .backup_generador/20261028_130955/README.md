# Sistema de Activos Fijos y Presupuestos - Grupo 7 (UAGRM - FICCT)

Proyecto con el alcance del **Sprint 1**, **Sprint 2** y **Sprint 3**:

| Sprint | Historias de usuario |
|---|---|
| 1 | HU-01 Iniciar sesion · HU-02 Registrar activos por categoria · HU-03 Asignar activos a responsables y ubicaciones |
| 2 | HU-04 Roles y permisos · HU-05 Codigo QR del activo · HU-06 Control de estado · HU-07 Depreciacion y valor en libros · HU-08 Mantenimientos · HU-09 Presupuesto anual · HU-10 Ejecucion presupuestaria |
| 3 | HU-11 Multiempresa y suscripcion (SaaS) · HU-12 Panel de la plataforma · HU-13 Bitacora de auditoria inmutable · HU-14 Consultas con IA · HU-15 Personalizacion por empresa · HU-16 Respaldos y restauracion · HU-17 Inventario movil con camara, GPS y voz · **Multiempresa real** (varias empresas con un solo login) · **Pasarela de pagos REAL** (Mercado Pago / PayPal / Stripe / QR Simple) · **Respaldos durables** (en la base de datos) |

### Documentos para leer

| Archivo | Que trouve |
|---|---|
| `LEEME_PUNTA_A_PUNTA.txt` | **El camino completo**: generar el proyecto, probarlo en local, crear la base en Neon, desplegar en Azure, configurar la pasarela y generar el APK |
| `LEEME_PASARELAS.txt` | Como configurar **cada pasarela** (Mercado Pago, PayPal, Stripe, QR Simple) paso a paso, que credenciales pedir, que evento suscribir y que URL de webhook registrar |
| `LEEME_MULTIEMPRESA_Y_PAGOS.txt` | Multiempresa, pagos y respaldos en detalle |
| `LEEME_INICIO.txt` | Como arrancar en local |
| `DESPLIEGUE_SPRINT3.txt` | Detalle del despliegue en Azure por perfiles |
| `README.md` | Este documento: referencia completa |

## Estructura

- `backend/`  -> Spring Boot 3 + PostgreSQL + JWT (puerto 8080)
- `frontend/` -> Angular standalone (puerto 4200)
- `mobile/`   -> App Flutter con las mismas funciones que la web: activos (ficha completa), mantenimientos, depreciacion, presupuestos, usuarios y roles
- `database/schema.sql` -> creacion de la base de datos (Sprint 1)
- `database/migrations/V3__sprint3.sql` -> migracion multiempresa del Sprint 3 (idempotente, la aplica el backend al arrancar)
- `backend/src/main/resources/db/V4__multiempresa_pagos.sql` -> cuenta global por persona, proveedor del pago, checksum y contenido durable de los respaldos (tambien idempotente)
- `database/seed_datos_ficticios.sql` -> datos de fabrica del Sprint 1 (ubicaciones, activos, asignaciones)
- `database/seed_sprint2_datos.sql` -> datos de fabrica del Sprint 2 (presupuestos, partidas, mantenimiento)
- `database/seed_multiempresa_datos.sql` -> datos de fabrica del multiempresa: la segunda empresa ("Sede Norte"), sus roles, permisos, configuracion y suscripcion, la cuenta global de cada persona y la membresia cruzada del administrador (un solo login para las dos empresas)
- `database/seed_sprint3_datos.sql` -> datos de fabrica del Sprint 3: rellena TODAS las tablas de negocio (asignaciones, historial de estados, mantenimientos, ejecuciones presupuestarias, pagos de suscripcion, verificaciones de inventario, consultas guardadas, respaldos, programacion de respaldos y bitacora de auditoria con cadena de hashes valida). Es idempotente.

Todos los seeds se aplican solos con `iniciar_proyecto.bat` y, despues de un reseteo total, la base queda completamente poblada con datos ficticios. Para un entorno limpio sin datos: `python iniciar_proyecto.py --sin-datos-demo`.

## Arranque automatico (recomendado)

Doble clic en `iniciar_proyecto.bat` (o `python iniciar_proyecto.py`): prepara PostgreSQL, arranca el backend y el
frontend y abre el navegador. `detener_proyecto.bat` lo detiene. Detalles en `LEEME_INICIO.txt`.

App movil (Flutter): `iniciar_todo_con_movil.bat` (web + movil), `iniciar_movil.bat` (solo movil) y `generar_apk.bat` (APK).
El lanzador elige el dispositivo y pasa la URL del backend con `--dart-define=API_URL=...`.

## Como correr el backend

```
cd backend
mvn spring-boot:run
```

(Si no tenes Maven instalado: instalalo desde https://maven.apache.org/download.cgi
o con `choco install maven` / `winget install Apache.Maven`.)

Antes, crear la base de datos ejecutando `database/schema.sql` en PostgreSQL
y ajustar usuario/clave en `backend/src/main/resources/application.properties`.

**Actualizacion desde el Sprint 1:** no hace falta ejecutar nada a mano. Al arrancar, el backend
(`ddl-auto=update` + `DatabaseInitializer`) agrega las tablas y columnas nuevas, quita la restriccion
CHECK de estados del Sprint 1, convierte los estados antiguos (`SIN_ASIGNAR`→`DISPONIBLE`,
`MANTENIMIENTO`→`EN_MANTENIMIENTO`, `BAJA`→`DADO_DE_BAJA`), crea los permisos nuevos, el rol `TECNICO`,
la categoria `Terrenos`, las areas iniciales y los parametros de depreciacion por categoria.
Todo es idempotente. Si preferis hacerlo con SQL: `psql -d activos_fijos_db -f database/migrations/V2__sprint2.sql`.

## Como correr el frontend

```
cd frontend
npm install
npm start
```

Luego abrir http://localhost:4200

> `npm start` sirve en http://localhost:4200 y usa rutas relativas `/api`: el archivo
> `proxy.conf.json` redirige esas llamadas al backend local en http://127.0.0.1:8080 (mismo
> origen para el navegador, sin CORS y sin problemas de IPv6). En produccion (`ng build`) el
> Angular se empaqueta dentro del backend, asi que tambien usa rutas relativas `/api`.
> Si el login devuelve `ECONNREFUSED`, `500` o `0 Unknown Error`, el backend no esta
> escuchando: ejecuta `verificar_estado.bat` para el diagnostico completo.

## Que incluye el Sprint 2

**HU-04 Roles y permisos.** Cada rol define permisos por modulo y accion (`ACTIVOS`, `DEPRECIACION`, `MANTENIMIENTO`,
`PRESUPUESTO`, `REPORTES`, `USUARIOS` × `LEER`, `CREAR`, `EDITAR`, `ELIMINAR`). Los permisos viajan en el JWT y se actualizan
en el siguiente inicio de sesion. El administrador crea, edita y desactiva roles (no se puede desactivar un rol con usuarios
activos) y siempre debe existir un administrador activo. El menu se arma segun los permisos del token.

**HU-05 QR.** Cada activo tiene un QR generado bajo demanda con ZXing a partir de su codigo unico (`ACT-2026-0001`).
Desde la ficha del activo se descarga la etiqueta en PNG o PDF o se imprime. Al escribir el codigo en el buscador de
activos se abre la ficha.

**HU-06 Estado.** Estados: Disponible, En uso, En mantenimiento, Inactivo y Dado de baja, con las transiciones del
diagrama de estados del perfil. Todo cambio exige motivo y queda en el historial con fecha y usuario. Dar de baja
requiere el permiso `ACTIVOS_ELIMINAR`; reactivar un activo dado de baja solo lo puede hacer un administrador.

**HU-07 Depreciacion.** Linea recta: `(valor de adquisicion − valor residual) ÷ vida util en meses`, parametrizada por
categoria. Un proceso programado (`app.depreciacion.cron`, por defecto el dia 1 de cada mes a las 02:00) genera el
periodo; tambien se recupera al arrancar y con el boton «Calcular periodos pendientes». Es idempotente (clave unica
activo + periodo). Un activo dado de baja deja de depreciarse desde el mes de su baja.

**HU-08 Mantenimientos.** Preventivos (fecha programada y periodicidad opcional) y correctivos. Iniciar un mantenimiento
pasa el activo a «En mantenimiento»; al finalizar (costo y tecnico) vuelve a su estado previo. Alertas de los que vencen
en 7 dias y de los vencidos, y costo total acumulado por activo.

**HU-09 / HU-10 Presupuestos.** Presupuesto por gestion y area (unico por area y gestion), con partidas cuya suma no
puede superar el monto aprobado. Estados Borrador → Aprobado → Cerrado; uno aprobado no se modifica. Sobre un presupuesto
aprobado se registran compromisos y ejecuciones; `saldo = planificado − (comprometido + ejecutado)` y ejecutar un
compromiso lo libera. El saldo se calcula en la misma transaccion con bloqueo de la partida.

## Endpoints nuevos (todos bajo `/api`, requieren `Authorization: Bearer <token>`)

| Metodo y ruta | Permiso |
|---|---|
| `GET /activos/{id}` · `GET /activos/codigo/{codigo}` | `ACTIVOS_LEER` |
| `GET /activos/{id}/qr` · `GET /activos/{id}/etiqueta.pdf` | `ACTIVOS_LEER` |
| `POST /activos/{id}/estado` · `GET /activos/{id}/historial-estados` | `ACTIVOS_EDITAR` (baja: `ACTIVOS_ELIMINAR`) |
| `GET /activos/{id}/mantenimientos` | `MANTENIMIENTO_LEER` |
| `GET /asignaciones/activo/{id}` · `GET /asignaciones/responsables` · `GET/POST /ubicaciones` | `ACTIVOS_*` |
| `GET /depreciacion/resumen` · `GET /depreciacion/activo/{id}` | `DEPRECIACION_LEER` |
| `POST /depreciacion/calcular?periodo=yyyy-MM` · `POST /depreciacion/activo/{id}/calcular` | `DEPRECIACION_CREAR` |
| `GET/POST /categorias` · `PUT /categorias/{id}` (parametros de depreciacion) | `ACTIVOS_*` / `DEPRECIACION_EDITAR` |
| `GET /mantenimientos` · `GET /mantenimientos/alertas` | `MANTENIMIENTO_LEER` |
| `POST /mantenimientos` · `PUT /mantenimientos/{id}` · `POST /mantenimientos/{id}/iniciar\|finalizar\|cancelar` | `MANTENIMIENTO_CREAR` / `_EDITAR` |
| `GET/POST /areas` · `PUT /areas/{id}` | `PRESUPUESTO_*` |
| `GET/POST /presupuestos` · `PUT /presupuestos/{id}` · `POST /presupuestos/{id}/aprobar\|cerrar` · `DELETE /presupuestos/{id}` | `PRESUPUESTO_*` |
| `GET/POST /presupuestos/{id}/partidas` · `PUT/DELETE /presupuestos/{id}/partidas/{partidaId}` | `PRESUPUESTO_*` |
| `GET /presupuestos/{id}/seguimiento` · `GET /presupuestos/{id}/ejecuciones` · `POST /ejecuciones` | `PRESUPUESTO_LEER` / `_CREAR` |
| `GET/POST/PUT/DELETE /roles` · `GET /roles/disponibles` · `/roles/permisos` | administrador |

Los errores se devuelven como `{"message": "..."}`: reglas de negocio incumplidas → `400`/`409`, sin permiso → `403`,
sesion vencida → `401`.

## Pruebas unitarias del backend

```
cd backend
mvn test -Dtest='DepreciacionCalculadoraTest,ReglasEstadoActivoTest,SaldoPartidaTest,EtiquetaQrTest'
```

La suite completa (`mvn test`) son **34 pruebas**. La de arranque (`ActivosBackendApplicationTests`)
necesita un PostgreSQL local en ejecucion, pero **no tienes que crear la base a mano**: el propio test
crea la base `activos_fijos_db_prueba`, le aplica `database/schema.sql` y la usa. Si el PostgreSQL esta
apagado, el error lo dice claramente.

## Asistente de IA (opcional, gratuito)

Sin claves el asistente funciona en **modo guiado** (sugerencias y constructor de consultas). Para habilitar el
lenguaje natural con modelos reales, doble clic en `configurar_ia.bat` (o `python configurar_ia.py`):

1. Crea una clave gratuita en Groq (https://console.groq.com/keys) y/o en Gemini (https://aistudio.google.com/app/apikey).
   Las claves de Groq empiezan por `gsk_` y las API keys de Gemini por `AIza` (los tokens `AQ.`/`ya29.` son OAuth y no sirven).
2. Pega la(s) clave(s) en el asistente; los modelos llevan valores por defecto vigentes
   (`openai/gpt-oss-120b` en Groq y `gemini-3.8-flash` en Gemini, plan gratuito sin tarjeta).
3. Reinicia con `iniciar_proyecto.bat`. El lanzador carga `ia_config.json` y se las pasa al backend
   (variables `GROQ_API_KEY`, `GROQ_MODEL`, `GEMINI_API_KEY`, `GEMINI_MODEL`); en Windows ademas quedan
   persistidas con `setx`. Una variable de entorno ya existente tiene prioridad sobre el archivo.

**En la nube (Azure App Service) la clave tambien se copia sola:** `desplegar_azure.py` lee `ia_config.json`
(o las variables de entorno de Windows, o `--groq-clave` / `--gemini-clave`) y las graba como variables de
entorno de App Service (cifradas en reposo por Azure; nunca en el codigo ni en el JAR). Al terminar imprime
si la IA quedo **configurada** o en **modo guiado**. Para cambiar la clave despues, sin rehacer el despliegue:

```
python desplegar_azure.py --solo-app
```

Ese mismo comando vuelve a sembrar los datos de fabrica y **cuenta las filas de cada tabla** para avisarte
de cualquier pantalla que se haya quedado vacia.

**Entrada por voz:** en la web el microfono del cuadro de pregunta usa la Web Speech API del navegador
(Chrome/Edge; requiere HTTPS o localhost y permiso de microfono) y en la app movil usa el reconocimiento del
sistema (`speech_to_text`). En ambos casos, si el permiso se deniega o no hay servicio de voz, se escribe la
pregunta; el dictado no consume cuota de los modelos ni requiere claves adicionales.

Comandos: `python configurar_ia.py --mostrar` (verificar) y `python configurar_ia.py --borrar` (eliminar claves).
El backend lee las claves de dos formas: la variable de entorno (la inyecta el lanzador) y, como respaldo, el propio
archivo `ia_config.json` (componente `IaConfigLoader`), de modo que la IA funciona aunque se ejecute el JAR fuera del
lanzador. Para comprobar que llegaron al backend: `GET /api/ia/estado` o el aviso verde/rojo en la pantalla
"Asistente IA"; `verificar_estado.bat` tambien informa de las claves detectadas.
El asistente distingue dos intenciones: las preguntas de datos se convierten en la especificacion JSON que
alimenta el motor con lista blanca, mientras que los saludos, las preguntas sobre el sistema, las dudas generales
o las peticiones fuera de alcance se responden como conversacion normal (sin inventar consultas). Mantiene el
historial de la conversacion (ultimos turnos), asi que las preguntas de seguimiento del tipo "y los que estan en
mantenimiento?" se interpretan en contexto. La salida se fuerza a JSON en ambos proveedores (`response_format` /
`responseMimeType`) y, si una respuesta viniera mal formada, se reintenta una vez con una instruccion correctiva.
**Si el asistente cae en modo guiado pese a haber claves**, el boton **"Probar conexion"** de esa pantalla
(`POST /api/ia/probar`) hace una llamada real a cada proveedor y muestra el codigo HTTP y el motivo exacto
(clave invalida 401/403, limite 429, modelo retirado o problema de red). Los modelos que los proveedores retiraron
(por ejemplo `llama-3.3-70b-versatile`, apagado por Groq el 2026-08-16, o los `gemini-1.5-*`) se sustituyen
automaticamente por un modelo vigente, tanto en el backend como en `configurar_ia.py`, sin que haya que reconfigurar.
La IA solo genera una especificacion JSON; el SQL lo construye el motor con lista blanca de 13 tablas y scope por
empresa, por lo que el modelo nunca toca SQL directamente. El archivo `ia_config.json` se ignora en git y en el
generador (contiene secretos).

## Exportar reportes a PDF y Excel

En la pantalla "Reportes" estan los botones **Exportar PDF** y **Exportar Excel**: envian la consulta construida
(POST autenticado con el token) a `/api/reportes/exportar/pdf` y `/api/reportes/exportar/excel`, que devuelven el
archivo listo para descargar.

## App movil: Sprint 2 y Sprint 3 en el mismo telefono

La app movil del Sprint 3 tiene **identidad propia**, asi que convive con la del Sprint 2
sin actualizarla: el telefono las muestra como dos apps distintas.

| | Sprint 2 (la que ya tienes) | Sprint 3 |
|---|---|---|
| Paquete Android | `com.uagrm.activos.activos_fijos_app` | `com.uagrm.activos.sp3` |
| Icono en el launcher | Activos Fijos App | **Activos Fijos SP3** |
| Bundle id iOS | `com.uagrm.activos.activosFijosApp` | `com.uagrm.activos.sp3` |

El APK se genera con `Generar_APK_Azure.bat` (toma la URL de Azure del perfil `.azure-despliegue-sp3`)
y queda como `ActivosFijos-SP3-movil-azure.apk`. Cada app habla con su propio backend.

## Despliegue en Azure (App Service F1 + Neon gratis)

```
python desplegar_azure.py --neon-cadena "postgresql://usuario:clave@ep-xxxx.neon.tech/neondb?sslmode=require"
```

El script es **idempotente**: se puede volver a ejecutar sobre el mismo despliegue. Hace todo el camino
(infraestructura, base, datos de fabrica, compilacion, subida) y al final **verifica que ninguna tabla de
negocio haya quedado vacia**.

Orden de los datos (importante para que nada salga en blanco):

1. `schema.sql` + usuarios de prueba + activos de ejemplo (antes de arrancar la app).
2. El backend arranca y aplica la migracion `V3` (empresa demo, `empresa_id`, planes, permisos).
3. El script **espera a que la base este lista** (empresa, areas, roles y categorias ya sembrados).
4. Se siembran los datos del Sprint 2 (presupuestos, partidas, mantenimiento) y del Sprint 3 (asignaciones,
   historial, ejecuciones, pagos, inventario, consultas guardadas, respaldos y bitacora).
5. Se cuentan las filas de cada tabla y se avisa de las vacias.

Si algo quedo a medias (por ejemplo, un despliegue antiguo), ejecuta:

```
python desplegar_azure.py --solo-app
```

Ese comando vuelve a compilar, redesplegar, **reaplicar las claves de la IA**, **resembrar los datos** y
**verificar las tablas**. Para el log del backend: `python desplegar_azure.py --logs`.

Detalles del despliegue por perfil (Sprint 3 usa `.azure-despliegue-sp3`, aislado del Sprint 1/2) en
`DESPLIEGUE_SPRINT3.txt`.

## Usuarios de prueba

Los de `database/fix_usuarios_prueba.sql`. El rol `TECNICO` se crea automaticamente; crea un usuario con ese rol desde
«Usuarios» para probar el flujo de mantenimientos.


---

## Multiempresa: varias empresas con un solo login (Sprint 3)

La identidad de la persona vive en la tabla `cuenta` (correo unico global, contrasena, estado) y las
**membresias** por empresa viven en `usuario` (una fila por empresa, unico por `empresa_id` + `correo`).
Asi una misma persona puede trabajar en varias empresas, con un rol distinto en cada una, sin duplicar contrasenas.

| Que se puede hacer | Como |
|---|---|
| Ver con que empresas tiene acceso | El login devuelve la lista `empresas`; tambien `GET /api/auth/mis-empresas` |
| Cambiar de empresa | El selector de la web (barra superior o menu lateral) o el bloque "MIS EMPRESAS" del menu lateral del movil: `POST /api/auth/cambiar-empresa` devuelve un token nuevo con el rol de esa empresa |
| Datos aislados | Cada tabla de negocio lleva `empresa_id` y Hibernate aplica el filtro de empresa en cada consulta |
| Datos de fabrica | El seed crea la empresa "Empresa Demo UAGRM - Sede Norte" con sus roles, activos y presupuesto; `admin@uagrm.edu.bo` es administrador de las dos empresas |

Usuarios de prueba:

| Correo | Contrasena | Empresas |
|---|---|---|
| `admin@uagrm.edu.bo` | `admin123` | Empresa Demo UAGRM **y** Sede Norte (cambio de empresa desde la web y el movil) |
| `norte@uagrm.edu.bo` | `norte123` | Solo Sede Norte |

## Pasarela de pagos REAL (Mercado Pago, PayPal, Stripe o QR Simple)

El sistema **no simula** los pagos: si no hay credenciales, la pantalla de suscripcion lo dice y la
contratacion devuelve un error claro (HTTP 503) en vez de "aprobar" un pago inventado.

| Variable de entorno | Para que sirve |
|---|---|
| `APP_PAGOS_PROVEEDOR` | `MERCADO_PAGO` (por defecto), `PAYPAL`, `STRIPE` o `QR` |
| `MERCADOPAGO_ACCESS_TOKEN` | Token de acceso de tu app en https://www.mercadopago.com.bo/developers/panel/app |
| `MERCADOPAGO_WEBHOOK_SECRET` | Secreto de la firma del webhook (opcional, pero recomendado) |
| `PAYPAL_CLIENT_ID` / `PAYPAL_CLIENT_SECRET` | Credenciales de https://developer.paypal.com/dashboard/applications |
| `PAYPAL_AMBIENTE` | `live` (por defecto) o `sandbox` |
| `STRIPE_SECRET_KEY` | Clave de tu cuenta en https://dashboard.stripe.com/apikeys (`sk_test_...` / `sk_live_...`) |
| `STRIPE_WEBHOOK_SECRET` | Secreto del webhook (`whsec_...`): permite validar la firma `Stripe-Signature` |
| `STRIPE_MONEDA` | Moneda que cobra Stripe (por defecto `USD`; Stripe no admite bolivianos) |
| `STRIPE_FACTOR_CONVERSION` | Factor para pasar de bolivianos a la moneda de Stripe (por ejemplo `6.9`) |
| `APP_PAGOS_QR_CLIENT_ID` / `APP_PAGOS_QR_CLIENT_SECRET` | Credenciales de QR Simple (Red Enlace / ATC) |
| `APP_PAGOS_QR_ID_ESTABLECIMIENTO` | Id del establecimiento registrado en ATC (obligatorio) |
| `APP_PAGOS_QR_BASE_URL` | `https://atcgwapitest.redenlace.com.bo/sandbox` (certificacion) o `https://api.redenlace.com.bo` (produccion) |
| `APP_PAGOS_QR_WEBHOOK_KEY` / `APP_PAGOS_QR_WEBHOOK_VALUE` | Cabecera y valor con los que ATC firma la notificacion del pago |
| `APP_PAGOS_MONEDA` | `BOB` (por defecto) o `USD` |
| `APP_PAGOS_FACTOR_CONVERSION` | Factor para pasar de bolivianos a la moneda de la pasarela (por ejemplo `6.9` para BOB -> USD) |
| `APP_PAGOS_SANDBOX` | `true` solo para demostraciones sin credenciales (el sistema lo avisa en pantalla) |
| `APP_URL_PUBLICA` | URL publica del backend, para armar el webhook y las url de retorno |

Como funciona:

1. La empresa elige plan y meses y pulsa "Contratar / renovar".
2. El backend crea el pago `PENDIENTE` y llama a la API real del proveedor para crear el checkout;
   la web y el movil abren la URL de pago del proveedor (Mercado Pago / PayPal / Stripe) o, con
   **QR Simple**, muestran el codigo QR para escanearlo con la app del banco.
3. El proveedor notifica al webhook `POST /api/pagos/webhook`. El backend **no se fia de la notificacion**:
   valida la firma que trae (Stripe: `Stripe-Signature`; QR Simple: la clave que definiste; Mercado Pago:
   `x-signature`/`x-hash`) y consulta el pago en la API del proveedor; solo entonces lo aprueba y extiende
   la suscripcion.
4. La suscripcion se renueva o cambia de plan y queda registrada en la bitacora de auditoria.

Ademas, `GET /api/pagos/{referencia}` consulta el estado en la pasarela (servidor a servidor): es el boton
"Ya pague: comprobar estado" que aparece cuando se paga con QR.

El metodo de pago se elige en la pantalla de suscripcion (web y movil): Mercado Pago, PayPal, Stripe y
QR Simple. Si el metodo elegido no tiene credenciales, la contratacion responde HTTP 503 diciendo que
credencial falta: el sistema nunca simula el cobro.

Para desplegar en Azure: define las variables en Windows y vuelve a ejecutar `python desplegar_azure.py`
(el script las guarda en App Service cifradas y te avisa si la pasarela queda sin configurar).

## Configurar las pasarelas paso a paso (guia completa)

Hay una guia detallada, proveedor por proveedor, en **`LEEME_PASARELAS.txt`** (todo en texto plano, se abre
con doble clic). Y hay un **asistente automatico** que hace la parte tediosa:

```
python configurar_pasarelas.py           # asistente: pide claves, las VALIDA contra la API real y las guarda
python configurar_pasarelas.py --verificar   # estado real de las 4 pasarelas en tu despliegue
python configurar_pasarelas.py --probar-webhook  # comprueba que el webhook responde
```

El asistente valida en vivo (por eso si una clave esta mal te lo dice al instante, no cuando llegue un
cliente): Mercado Pago (`/users/me`), PayPal (token OAuth2), Stripe (`/v1/account`) y QR Simple
(OAuth2 de ATC). Ademas imprime la **URL exacta del webhook** que tienes que registrar en cada panel.

Resumen de los 4 proveedores y de donde sale cada credencial:

| Proveedor | Donde pedir las claves | Evento que debes suscribir en el webhook |
|---|---|---|
| Mercado Pago | https://www.mercadopago.com.bo/developers/panel/app | `payment` |
| PayPal | https://developer.paypal.com/dashboard/applications | `PAYMENT.CAPTURE.COMPLETED` |
| Stripe | https://dashboard.stripe.com/apikeys | `checkout.session.completed` |
| QR Simple (Red Enlace / ATC) | Alta de comercio con ATC (te dan `client_id`, `client_secret` e `id de establecimiento`) | Notificacion al `webhook.url` que mandas al crear el QR |

La URL del webhook es siempre la misma en los cuatro:

```
https://TU-WEBAPP.azurewebsites.net/api/pagos/webhook
```

> Si no te habilitan comercio con ATC, arranca con **Stripe** o **Mercado Pago** (no requieren tramites
> especiales) y activa QR Simple despues.

## Desplegar la web y la API en el MISMO sitio (si funciona?)

**Si, es la opcion correcta y ya esta implementada.** Como funciona:

1. El frontend Angular se compila con `apiUrl='/api'` y sus archivos se copian dentro del JAR, en
   `backend/src/main/resources/static`. Al desplegar, **un solo App Service** sirve la web y la API.
2. El navegador pide `https://TU-WEBAPP.azurewebsites.net/api/...`: misma origen, sin CORS, sin dominios
   cruzados, sin certificado que configurar.
3. El webhook `POST /api/pagos/webhook` es publico (`permitAll`) y **el CSRF esta deshabilitado**
   (imprescindible: si no, Stripe/Mercado Pago/ATC rechazan la notificacion).
4. `APP_URL_PUBLICA` se fija automaticamente en el despliegue con la URL real de tu web. **Sin esta
   variable los webhooks y los retornos apuntan a `localhost` y ningun pago se confirmaria**, por eso el
   script de despliegue la vuelve a aplicar cada vez.
5. La CSP del backend quedo ajustada: `style-src 'self' 'unsafe-inline'` (los estilos en linea de Angular),
   `img-src 'self' data: blob:` (la imagen del QR en base64), `script-src 'self'`. La web embebida se
   sirve por su propia cadena (`SpaSecurityConfig`, sin CSP) para que **siempre** cargue con estilos y
   muestre el QR; la cadena de la API, que si lleva CSP, responde con esas directivas.

Comprobado localmente con el build de produccion dentro del JAR:

| Comprobacion | Resultado |
|---|---|
| `GET /` | 200 `text/html` (index de Angular) |
| `GET /styles-*.css`, `/main-*.js`, `/favicon.ico` | 200 con su `content-type` |
| `GET /suscripcion` (ruta profunda de la SPA) | 200 `text/html` (fallback de la SPA) |
| `GET /api/public/planes` | 200 (mismo origen, sin CORS) |
| `POST /api/auth/login` | 200 con token JWT |
| `apiUrl` dentro del bundle compilado | `"/api"` (ruta relativa: nunca cruza de dominio) |

Lo unico que **no** se puede compartir entre si es el webhook de cada proveedor, porque cada uno te
da su propio secreto de firma: son 4 registros distintos en 4 paneles distintos.

Comprobacion de que todo funciona en el sitio desplegado:

```
python configurar_pasarelas.py --verificar    # te dice que pasarelas hay y si el webhook responde
```

## App movil apuntando a Azure (APK)

| Tema | Como esta resuelto |
|---|---|
| URL del backend | Toda la app usa `ApiConfig.baseUrl`; **no hay ninguna URL fija en el codigo**. Se pasa al compilar: `--dart-define=API_URL=https://TU-WEBAPP.azurewebsites.net` (el `.bat` lo toma solo del perfil `.azure-despliegue-sp3`) |
| Credenciales | Se envia `Authorization: Bearer <token>` en cada llamada; el token se guarda cifrado en el dispositivo |
| Arranque lento | El plan F1 se apaga cuando no hay visitas: la primera peticion puede tardar. Los timeouts de API y de login son de **60 s** y el mensaje de error explica que es el "cold start" de Azure |
| Android | Manifest con `INTERNET`, `CAMERA`, `LOCATION`, `RECORD_AUDIO`; `usesCleartextTraffic` y `network_security_config` para `azurewebsites.net` |
| Convivir con Sprint 2 | `applicationId=com.uagrm.activos.sp3` (distinto del Sprint 2): se instalan **las dos apps** en el mismo telefono |
| Navegacion | Todas las pantallas se alcanzan desde el menu lateral y siempre hay forma de volver |

Generar el APK: en Windows, `Generar_APK_Azure.bat` (compila y deja `ActivosFijos-SP3-movil-azure.apk`).

## Respaldos que funcionan de verdad

| Accion | Donde |
|---|---|
| Crear un respaldo | Pantalla "Respaldos" -> "Crear respaldo manual" (o `POST /api/respaldos`) |
| Descargarlo | "Descargar" (`GET /api/respaldos/{id}/descargar`) |
| Restaurarlo | "Restaurar" (`POST /api/respaldos/{id}/restaurar`): antes de tocar nada se crea un respaldo de seguridad, la restauracion va en una transaccion (si algo falla se revierte) y despues se reajustan las secuencias de ids |
| Programarlos | "Programacion" (diaria o semanal) |

El archivo se guarda **dentro de la base de datos** (columna `respaldo.contenido`, tipo `bytea`) y tambien
en disco como cache. Asi el respaldo sobrevive a reinicios del contenedor de Azure (donde el disco es
efimero) y se puede descargar aunque el archivo local ya no exista. Cada respaldo guarda su SHA-256 y al
restaurar se verifica: si el archivo fue alterado, la restauracion se rechaza.

Las carpetas son portables (relativas al proyecto, configurables con `APP_RESPALDOS_CARPETA` y
`APP_ARCHIVOS_CARPETA`), asi que funcionan igual en Windows, en el servidor y en Azure.

Sobre el error "El contenido del respaldo ya no esta disponible" (HTTP 404): ocurre con los respaldos
**antiguos**, que solo guardaban la ruta del archivo y no el contenido (el archivo ya no existia en el
disco efimero de Azure). Ahora:

* la lista marca esos registros con `descargable: false`, la web y el movil los muestran como
  "sin contenido" y deshabilitan "Descargar"/"Restaurar" con el motivo a la vista;
* al abrir la pantalla de respaldos, si la empresa no tiene ningun respaldo que se pueda descargar, el
  backend **crea uno real** (con el contenido ya sembrado, para que restaurarlo no borre los datos de
  fabrica). Asi la pantalla nunca queda vacia ni con registros que fallan;
* el seed de fabrica ya no inserta respaldos ficticios sin contenido.

## Verificacion realizada (Sprint 3)

| Que se comprobo | Resultado |
|---|---|
| Suite E2E de Sprint 3 (8 bloques) | 18 OK / 0 FALLAS |
| Suite E2E de la ronda 5 (respaldos, multiempresa, Stripe/QR) | 25 OK / 0 FALLAS |
| Regresion Sprint 1 + 2 + 3 (50 chequeos) | 50 OK / 0 fallos |
| Tests automaticos del backend (JUnit) | 34/34 OK |
| Tests de la app movil (Flutter) | 8/8 OK (incluye la compilacion de toda la app) |
| Compilacion de produccion de la web | `ng build --configuration production` OK |
| Analisis estatico del movil | la compilacion de TODA la app (toda pantalla y servicio) esta incluida en los tests de Flutter |
| Instalacion limpia (esquema + migraciones + semillas) | 5/5 semillas OK, sin pantallas vacias |
| Generador (roundtrip SHA-256 + idempotencia + respaldo) | 546 archivos, 0 fallos |
| Pasarela de pagos contra la API real | la API de Mercado Pago responde 409 con su propio error (no simula) |
| Pasarela sin credenciales | 503 con mensaje claro (dice que credencial falta), sin cobrar ni simular |
| Stripe y QR sin credenciales | 503 nombrando la credencial que falta; el webhook con firma invalida no aprueba ningun pago |
| Firma del webhook de Stripe | se valida `Stripe-Signature` (HMAC-SHA256, tolerancia de 5 min) y despues se consulta la API de Stripe |
| Respaldos antiguos | se marcan `descargable: false`, el boton se deshabilita con el motivo y el backend crea un respaldo real al arrancar |
| Webhook sin firma | 200, sin error 500, y no aprueba nada sin verificar con el proveedor |
| Aislamiento entre empresas | el token de la empresa 2 solo ve sus propios activos |
| Validadores del configurador contra las APIs reales | Stripe 401, Mercado Pago 403, PayPal 400 y QR Simple 400: los 4 detectan claves falsas |
| `APP_URL_PUBLICA` en Azure | se fija en el despliegue (sin ella los webhooks apuntarian a localhost y no se confirmaria ningun pago) |
| CSP del backend | `style-src 'self' 'unsafe-inline'` + `img-src 'self' data: blob:`; la web embebida se sirve por su propia cadena, sin CSP, para que siempre cargue con estilos y muestre el QR |
| Web + API en el mismo sitio | verificado con el build de produccion dentro del JAR: `/` 200, assets 200, ruta profunda 200, `/api/public/planes` 200, login 200 |
| Prueba de arranque del backend | crea su propia base `activos_fijos_db_prueba`: `mvn test` pasa en un equipo limpio |
| Movil apuntando a Azure | sin URLs fijas en el codigo, timeouts de 60 s por el cold start del plan F1 |
| Paridad de endpoints (movil -> backend) | las **72** rutas que usa el movil existen en el backend (0 faltantes); los 4 endpoints que no usa el movil son del webhook, de solo-web o sin uso |


## Agregar empresas (multiempresa)

Hay tres caminos, todos en el mismo backend:

| Quien | Como | Que pasa |
|---|---|---|
| Cualquier usuario con sesion | Selector de empresa (web: barra superior o menu lateral; movil: menu lateral) -> **+ Agregar empresa** | La empresa nueva se crea con 15 dias de prueba y el usuario queda como **administrador** de ella; aparece de inmediato en el selector y se puede cambiar a ella sin volver a iniciar sesion |
| Super Admin | "Administracion de plataforma" (web) | Ve todas las empresas de la plataforma, su uso y sus limites |
| Visitante | Boton "Registra tu empresa aqui" (pantalla de acceso) | Alta publica con plan y 15 dias de prueba (el cobro real se hace despues con Mercado Pago o PayPal) |

Endpoint: `POST /api/auth/agregar-empresa` (con token). No pide contrasena porque la identidad es la misma
cuenta global del usuario; si el NIT ya existe responde 409.

El boton **+ Agregar empresa** esta SIEMPRE visible (barra superior y menu lateral de la web, menu lateral
del movil), aunque todavia no tengas mas de una empresa: antes se escondia dentro del bloque del selector
y por eso no se veia. Si acabas de actualizar y aun no te aparece, cierra sesion y vuelve a entrar (el
token guarda el rol y las empresas de la sesion) o pulsa "Actualizar" en el navegador.

## Nota sobre la instalacion local (importante)

El lanzador (`iniciar_proyecto.bat`) **borra y recrea la base en cada arranque**. Las semillas se aplican
**despues** de que el backend arranque, en este orden:

1. `fix_usuarios_prueba.sql` (los usuarios de prueba y sus cuentas)
2. `seed_datos_ficticios.sql` (activos y ubicaciones de ejemplo)
3. `seed_sprint2_datos.sql` (presupuestos, partidas, mantenimiento)
4. `seed_sprint3_datos.sql` (inventario, consultas, programacion de respaldos, bitacora, IA...)
5. `seed_multiempresa_datos.sql` (segunda empresa y membresia cruzada)

Si se siembran antes de que el backend cree la columna `empresa_id`, el script falla y la aplicacion
arranca con las tablas vacias. Al final el lanzador imprime el conteo de cada tabla y avisa si alguna
quedo vacia.

Ademas, el rol **ADMINISTRADOR** ahora recibe *todos* los permisos del catalogo en cada arranque
(migracion `V5__permisos_admin.sql`): antes, si la base se creaba en un orden distinto, el rol
administrador se quedaba sin `ACTIVOS_*`, `PRESUPUESTO_*`, `REPORTES_LEER` o `USUARIOS_*` y el menu
de la web y del movil perdia esos modulos.
