# Activos Fijos y Presupuestos - App movil (Flutter)

Cliente movil del sistema. Tiene **las mismas funciones que la aplicacion web** y usa el mismo backend
(`/api`), con los mismos roles y permisos: el menu y cada boton aparecen solo si el usuario tiene el permiso.

## Modulos

| Modulo | Funciones |
|---|---|
| **Inicio de sesion** (HU-01) | Ingreso con correo y contrasena, bloqueo temporal con cuenta regresiva, usuarios de prueba (`mostrarUsuariosPrueba` en `login_screen.dart`), cierre por token vencido, respuesta 401 o 30 min de inactividad |
| **Activos** (HU-02/05) | Lista con busqueda y filtros por estado y categoria, abrir por codigo (QR), alta y edicion (valor residual, inicio de depreciacion), aviso si el activo ya no es editable |
| **Ficha del activo** | Pestanas **Datos**, **Asignacion** (HU-03: asignar/reasignar, nueva ubicacion, historial), **Estado** (HU-06: cambio con motivo, baja con confirmacion, historial), **Etiqueta QR** (HU-05: PNG, PDF e impresion), **Depreciacion** (HU-07: indicadores, tabla, calcular periodos) y **Mantenimientos** (HU-08: historial, costo total, programar) |
| **Mantenimientos** (HU-08) | Alertas (vencidos / proximos 7 dias), filtros, programar preventivo o correctivo, reprogramar, iniciar, finalizar (costo y tecnico) y cancelar |
| **Depreciacion** (HU-07) | Totales, detalle por activo, calcular periodos pendientes y parametros por categoria (vida util, % residual, metodo) |
| **Presupuestos** (HU-09/10) | Lista con filtros, nuevo presupuesto y nueva area, eliminar borrador; detalle con aprobar, cerrar, cambiar monto, partidas (alta/edicion/baja), seguimiento, compromisos y ejecuciones |
| **Usuarios** | Alta, edicion, desactivar y reactivar, con validacion de contrasena segura |
| **Roles y permisos** (HU-04, solo administrador) | Roles (crear, editar permisos, desactivar, reactivar) y catalogo de permisos (crear, editar, eliminar) |
| **Reportes y BI** (HU-16) | Tablero con KPIs y distribuciones, **constructor de consultas** (tabla, columnas, filtros `= != > >= < <= LIKE IN BETWEEN IS NULL`, orden, limite y agregacion `COUNT/SUM/AVG/MIN/MAX` con agrupacion), consultas guardadas (ejecutar, exportar, eliminar) y exportacion PDF/Excel por el menu de compartir |
| **Asistente IA** (HU-14) | Preguntas en lenguaje natural **por voz o teclado**, memoria de la conversacion (ultimos turnos), respuestas conversacionales sin tabla, diagnostico `Probar conexion` por proveedor y modo guiado sin clave |
| **Inventario fisico** (HU-17) | Verificaciones por escaneo QR, GPS y foto de evidencia, con alternativa manual si se niegan permisos |
| **Auditoria** (HU-13) | Bitacora con filtros y verificacion de la cadena de hashes SHA-256 |
| **Respaldos** (HU-15) | Crear, listar, restaurar y programar respaldos diarios/semanales |
| **Suscripcion** (HU-11) | Plan actual, limites/uso y contratacion o cambio de plan (pago sandbox) |
| **Personalizacion** (HU-13) | Colores de marca, idioma es/en, posicion del menu y logo (1 MB) |
| **Plataforma** (HU-12, solo Super Admin) | Metricas de la plataforma y activar/suspender empresas |
| **Registro de empresa** (HU-11) | Alta publica de empresa con su administrador y plan (sin sesion) |

### Diferencias con la web (adaptaciones al celular)

- Las tablas se muestran como tarjetas; la tabla de depreciacion se desplaza horizontalmente.
- Las listas desplegables abren una hoja inferior con buscador cuando hay muchas opciones.
- **Descargar PNG / PDF** abre el menu de compartir del sistema (guardar en archivos, enviar por WhatsApp, etc.) y
  **Imprimir** abre el dialogo de impresion del sistema con la etiqueta en PDF.
- Los formularios se abren como hojas inferiores o pantallas completas en lugar de ventanas modales.

## Estructura de `lib/`

```
config/      api_config.dart         URL del backend (--dart-define=API_URL=...)
models/      activo, categoria, ficha (depreciacion y mantenimiento), presupuesto, seguridad, json_util
services/    api_client (HTTP + token + errores), auth_service (sesion), un servicio por modulo
screens/     una pantalla por modulo + navegacion.dart (menu lateral segun permisos)
widgets/     comunes.dart (tarjetas, KPIs, selector, fecha, dialogos), tabla_depreciacion, etiqueta_util
```

## Ejecutar

```
flutter pub get
flutter run --dart-define=API_URL=http://<IP-de-tu-PC>:8080/api
```

Emulador Android: `http://10.0.2.2:8080/api`. Chrome/Windows: `http://localhost:8080/api` (valor por defecto).
El lanzador del proyecto (`iniciar_movil.bat`) elige el dispositivo y pasa la URL correcta.

## Generar el APK de producción apuntando a Azure

### Requisitos previos en Windows (una sola vez)

1. **Modo de programador activado**: Flutter usa symlinks para los plugins. Si `flutter pub get`
   falla con *"Building with plugins requires symlink support"*, ejecuta
   `Habilitar_modo_desarrollador.bat` (doble clic, acepta el permiso de administrador) o bien
   `start ms-settings:developers` y activa "Modo de programador".
2. **Android SDK completo** (si `flutter doctor` marca el toolchain Android):
   - en Android Studio: *Settings → Languages & Frameworks → Android SDK → SDK Tools*, marca
     **Android SDK Command-line Tools (latest)** y pulsa Apply;
   - luego ejecuta `flutter doctor --android-licenses` y responde `y` a todo.

El APK release se conecta por HTTPS al App Service desplegado; el celular solo necesita
internet (no hace falta la PC encendida ni estar en la misma red).

Opción automática (recomendada): desde la carpeta raíz del proyecto, doble clic en
**`Generar_APK_Azure.bat`**. Toma la URL de Azure sola del perfil de despliegue (`.azure-despliegue-sp3/config.json`, el del Sprint 3) y genera `ActivosFijos-SP3-movil-azure.apk` en la raíz.

### Como se navega en la app (igual que la web)

- **Inicio**: al abrir la app (o al iniciar sesion) aparece la pantalla **Inicio** con
  una tarjeta por cada modulo permitido (Activos, Mantenimientos, Depreciacion,
  Presupuestos, Inventario fisico, Reportes y BI, Asistente IA, Usuarios, Roles,
  Suscripcion, Respaldos, Auditoria, Personalizacion y Administracion de plataforma).
  Toca una tarjeta y el modulo se abre.
- **Menu lateral (boton de las rayitas, esquina superior izquierda)**: disponible en
  **todas** las pantallas, para saltar de un modulo a otro en cualquier momento.
- **Boton de casa (arriba a la derecha)**: vuelve al Inicio desde cualquier modulo.
- **Boton Atras del telefono**: dentro de un modulo vuelve al Inicio (no cierra la app);
  en una pantalla de detalle (activo, presupuesto) vuelve a la lista.

### Instalar junto con el Sprint 2 (dos apps en el mismo telefono)

La app del Sprint 3 tiene **identidad propia**, asi que el telefono la instala AL LADO
de la del Sprint 2 y no la actualiza:

| | Sprint 2 (la que ya tienes) | Sprint 3 (esta) |
|---|---|---|
| Paquete Android | `com.uagrm.activos.activos_fijos_app` | `com.uagrm.activos.sp3` |
| Nombre en el launcher | Activos Fijos App | **Activos Fijos SP3** |
| Bundle id iOS | `com.uagrm.activos.activosFijosApp` | `com.uagrm.activos.sp3` |

Al abrir el launcher veras los dos iconos con nombres distintos; cada una habla con su
propio servidor (el Sprint 2 con su backend, el Sprint 3 con el de Azure).
Equivalente por consola:

```cmd
python iniciar_proyecto.py --apk
python iniciar_proyecto.py --apk --api-url https://TU-WEBAPP.azurewebsites.net
```

A mano con Flutter (sin los lanzadores):

```cmd
cd mobile
flutter pub get
flutter build apk --release --dart-define=API_URL=https://TU-WEBAPP.azurewebsites.net/api
```

El APK queda en `mobile\build\app\outputs\flutter-apk\app-release.apk`. Para APKs más
pequeños por arquitectura, agrega `--split-per-abi` (genera uno por arquitectura: arm64, armeabi-v7a, x86_64).
Instalación: copia el APK al celular y permite "orígenes desconocidos"; si hay un celular
conectado por USB con depuración USB, el lanzador lo instala automáticamente con adb.

> Nota: la URL siempre termina en `/api` (sin barra final). El lanzador la normaliza; si la
> escribes a mano, recuerda ese sufijo. El permiso `INTERNET` ya está declarado en el
> `AndroidManifest.xml`; como Azure usa HTTPS, no aplica la restricción de tráfico en claro.

### "El servidor tardó demasiado en responder" en el teléfono

Ese mensaje es un tiempo de espera del cliente HTTP (12 s en el login, 25 s en el resto);
**no** significa que el servidor de Azure esté caído. Diagnóstico en dos minutos:

1. **Mira la línea `Servidor: …` al pie de la pantalla de login de la app.**
   - `http://localhost:8080/api` → el APK se compiló sin la URL de Azure (valor por defecto).
   - `http://192.168.x.x:8080/api` o `http://10.0.2.2:8080/api` → es el APK de pruebas LAN;
     fuera de esa WiFi (o con datos móviles) nunca llegará al servidor.
   - Valor correcto: `https://TU-WEBAPP.azurewebsites.net/api`.
   Si el valor es cualquiera de los dos primeros, desinstala la app y genera un APK nuevo
   con `Generar_APK_Azure.bat`; en el log debe aparecer
   `Generando el APK (release) apuntando a https://TU-WEBAPP.azurewebsites.net/api`.
2. **Abre esa misma URL HTTPS en el navegador del teléfono.** Si la web de login carga, la
   red funciona y el problema era solo la URL del APK. Si tampoco carga, la red del teléfono
   está bloqueando el acceso (WiFi de universidad/empresa, VPN, DNS): prueba con datos móviles.
3. El mensaje de error de la app ahora incluye el host al que intenta conectar, para que se
   distinga de un vistazo una URL local equivocada de un problema de red.

Pruebas: `flutter test` (formatos y modelos, no requieren servidor).
