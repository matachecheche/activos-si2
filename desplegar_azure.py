#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
desplegar_azure.py - Despliegue automatico del "Sistema de Activos Fijos y Presupuestos"
                      (Grupo 7, UAGRM - FICCT) en Microsoft Azure con cuenta de estudiante.

Que hace (todo en un solo grupo de recursos, para poder borrarlo todo con un comando):
  1. Verifica e instala las herramientas necesarias (Azure CLI, JDK, Node, Maven se descarga solo).
  2. Inicia sesion en Azure (sirve la cuenta "Azure for Students" / cuenta estudiantil).
  3. Crea la infraestructura en el plan GRATUITO / mas economico para estudiante:
       - Azure App Service, plan F1 (Linux, Java) .............. $0 / mes
       - Base de datos PostgreSQL, por defecto en Neon (gratis). $0 / mes
         (alternativa --bd azure: Azure Database for PostgreSQL B1MS, consume credito)
  4. Prepara el codigo:
       - ajusta la version de Java del pom a la soportada por Azure;
       - agrega dos archivos para servir el Angular dentro del mismo backend (mismo origen, sin CORS);
       - compila el frontend (Angular) y lo incrusta en el JAR de Spring Boot;
       - compila el backend con Maven.
  5. Crea la base de datos, aplica schema.sql y los datos de prueba con 'az postgres flexible-server execute'.
  6. Despliega el JAR en App Service y prueba el inicio de sesion.

USO (desde la carpeta raiz del proyecto, donde estan backend/, frontend/ y database/):
    python desplegar_azure.py                 despliegue completo (Neon gratis + App Service F1)
    python desplegar_azure.py --bd azure      igual, pero la BD en Azure PostgreSQL (consume credito)
    python desplegar_azure.py --neon-cadena "postgresql://usuario:clave@host.neon.tech/neondb?sslmode=require"
    python desplegar_azure.py --solo-app      recompila y vuelve a desplegar solo la aplicacion
    python desplegar_azure.py --preparar      solo prepara/compila localmente (no toca Azure)
    python desplegar_azure.py --estado        muestra los recursos y la URL publica
    python desplegar_azure.py --logs          muestra los logs en vivo (Ctrl+C para salir)
    python desplegar_azure.py --pausar        detiene PostgreSQL para no gastar credito
    python desplegar_azure.py --reanudar      vuelve a iniciar PostgreSQL
    python desplegar_azure.py --eliminar      borra TODOS los recursos (pide confirmacion)
    python desplegar_azure.py --dry-run       muestra lo que haria sin ejecutar nada

Opciones:
    --region eastus            region de Azure (por defecto eastus; ej. brazilsouth, southcentralus)
    --suscripcion <id/nombre>  elige la suscripcion si tienes varias
    --sin-datos-demo           no carga los datos ficticios (si crea usuarios de prueba)
    --confirmar                no pregunta confirmacion (util para --eliminar)

Requisitos en Windows: Python 3.8+, Azure CLI, JDK 17 o superior, Node.js 18+.
No necesita Maven instalado: el script lo descarga solo a la carpeta .tools.
Solo usa la libreria estandar de Python.
"""
import argparse
import datetime
import glob
import json
import os
import random
import re
import secrets
import shutil
import string
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile

# --------------------------------------------------------------------------- constantes globales

ES_WINDOWS = os.name == "nt"
RAIZ_PROYECTO = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.join(RAIZ_PROYECTO, "backend")
FRONTEND = os.path.join(RAIZ_PROYECTO, "frontend")
DATABASE = os.path.join(RAIZ_PROYECTO, "database")
TOOLS = os.path.join(RAIZ_PROYECTO, ".tools")
# HU-11/Sprint 3: perfil aislado para el SEGUNDO despliegue. Nunca reutiliza el
# config de Sprint 1/2 (".azure-despliegue"), asi se crean otra web Azure y otra
# Neon con sufijo aleatorio propio. Se puede cambiar con --perfil o AZURE_PERFIL.
PERFIL_DEFECTO = os.environ.get("AZURE_PERFIL", ".azure-despliegue-sp3")
CARPETA_CONFIG = os.path.join(RAIZ_PROYECTO, PERFIL_DEFECTO)
ARCHIVO_CONFIG = os.path.join(CARPETA_CONFIG, "config.json")


def fijar_perfil(nombre):
    """Cambia la carpeta de perfil (config.json + credenciales) de este despliegue."""
    global CARPETA_CONFIG, ARCHIVO_CONFIG
    if not nombre.startswith("."):
        nombre = "." + nombre
    CARPETA_CONFIG = os.path.join(RAIZ_PROYECTO, nombre)
    ARCHIVO_CONFIG = os.path.join(CARPETA_CONFIG, "config.json")
    return CARPETA_CONFIG

MAVEN_VERSION = "3.9.9"
MAVEN_URL = ("https://archive.apache.org/dist/maven/maven-3/%s/binaries/apache-maven-%s-bin.zip"
             % (MAVEN_VERSION, MAVEN_VERSION))

REGION_DEFECTO = "eastus"
PG_VERSION = "16"
PG_SKU = "Standard_B1MS"          # servidor burstable, el mas barato de PostgreSQL
PG_STORAGE_GB = "32"
PG_USUARIO = "activosadmin"
NOMBRE_BD = "activos_fijos_sp3"   # base aislada del segundo stack (Sprint 3)
APP_SERVICE_SKU = "F1"            # plan GRATUITO de App Service
RUNTIME_DEFECTO = "JAVA:21-java21"

# Motores de base de datos soportados
TIPO_BD_AZURE = "azure"           # Azure Database for PostgreSQL flexible (consume credito)
TIPO_BD_NEON = "neon"             # Neon serverless Postgres, plan gratuito
SQLRUNNER_DIR = os.path.join(TOOLS, "sqlrunner")

DRY = False                       # se activa con --dry-run

# --------------------------------------------------------------------------- colores de consola

class C:
    RESET = "\033[0m"
    AZUL = "\033[36m"
    VERDE = "\033[32m"
    AMARILLO = "\033[33m"
    ROJO = "\033[31m"
    NEGRITA = "\033[1m"


def habilitar_colores_windows():
    """Activa la salida de color en la consola de Windows 10+."""
    if not ES_WINDOWS:
        return
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        modo = ctypes.c_ulong()
        manejador = kernel32.GetStdHandle(-11)         # STD_OUTPUT_HANDLE
        if kernel32.GetConsoleMode(manejador, ctypes.byref(modo)):
            kernel32.SetConsoleMode(manejador, modo.value | 0x0004)
    except Exception:
        pass


def titulo(texto):
    print("\n" + C.NEGRITA + C.AZUL + "=" * 70)
    print(" " + texto)
    print("=" * 70 + C.RESET)


def ok(texto):
    print(C.VERDE + "  [OK] " + C.RESET + texto)


def info(texto):
    print(C.AZUL + "  .. " + C.RESET + texto)


def aviso(texto):
    print(C.AMARILLO + "  [AVISO] " + C.RESET + texto)


def error(texto):
    print(C.ROJO + "  [ERROR] " + C.RESET + texto)


def fatal(texto):
    error(texto)
    sys.exit(1)


# --------------------------------------------------------------------------- utilidades de proceso

# Secretos que nunca deben quedar impresos en la consola ni en los logs.
CLAVES_SECRETAS = ("GROQ_API_KEY", "GEMINI_API_KEY", "APP_JWT_SECRET",
                   "SPRING_DATASOURCE_PASSWORD", "PGPASSWORD", "APP_SUPERADMIN_PASSWORD",
                   "MERCADOPAGO_ACCESS_TOKEN", "MERCADOPAGO_WEBHOOK_SECRET",
                   "PAYPAL_CLIENT_SECRET", "PAYPAL_CLIENT_ID",
                   "STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET",
                   "APP_PAGOS_QR_CLIENT_ID", "APP_PAGOS_QR_CLIENT_SECRET",
                   "APP_PAGOS_QR_ID_ESTABLECIMIENTO", "APP_PAGOS_QR_WEBHOOK_VALUE")


def enmascarar(texto):
    """Oculta el valor de las variables sensibles en las lineas de comando que se imprimen."""
    for nombre in CLAVES_SECRETAS:
        texto = re.sub(re.escape(nombre) + r"=[^\s\"]*", nombre + "=****", texto)
    return texto


def ejecutar(cmd, cwd=None, env=None, mostrar=True):
    """Ejecuta un comando mostrandolo; con --dry-run solo lo imprime. Devuelve el codigo de salida."""
    texto = " ".join('"%s"' % p if " " in p else p for p in cmd)
    if mostrar:
        print(C.AMARILLO + "  $ " + C.RESET + enmascarar(texto))
    if DRY:
        return 0
    proceso = subprocess.run(cmd, cwd=cwd, env=env)
    return proceso.returncode


def capturar(cmd, cwd=None, env=None):
    """Ejecuta un comando y devuelve (codigo, stdout_texto). En dry-run devuelve (0, '')."""
    if DRY:
        texto = " ".join('"%s"' % p if " " in p else p for p in cmd)
        print(C.AMARILLO + "  $ " + C.RESET + enmascarar(texto) + C.AZUL + "   (simulado)" + C.RESET)
        return 0, ""
    return capturar_real(cmd, cwd, env)


def capturar_real(cmd, cwd=None, env=None):
    """Como capturar(), pero siempre ejecuta de verdad (lo usan las comprobaciones locales)."""
    try:
        proceso = subprocess.run(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)
        salida = proceso.stdout.decode("utf-8", "replace") + proceso.stderr.decode("utf-8", "replace")
        return proceso.returncode, salida
    except FileNotFoundError:
        return 127, ""


def json_tolerante(texto):
    """
    Parsea JSON aunque la salida traiga avisos de stderr mezclados delante o detras
    (p. ej. el warning de cryptography de 32 bits que imprime el CLI de Azure).
    Devuelve None si no encuentra ningun JSON valido.
    """
    if not texto:
        return None
    try:
        return json.loads(texto)
    except json.JSONDecodeError:
        pass
    decodificador = json.JSONDecoder()
    for marca in ("[", "{"):
        pos = texto.find(marca)
        while pos >= 0:
            try:
                objeto, _ = decodificador.raw_decode(texto[pos:])
                return objeto
            except json.JSONDecodeError:
                pos = texto.find(marca, pos + 1)
    return None


def comando_windows(ruta):
    """Los .cmd/.bat de Windows no se ejecutan directo con CreateProcess: se envuelven en cmd /c."""
    if ES_WINDOWS and ruta.lower().endswith((".cmd", ".bat")):
        return ["cmd", "/c", ruta]
    return [ruta]


def az_cmd():
    """Devuelve el comando base para invocar Azure CLI (en Windows az es az.cmd)."""
    return comando_windows(shutil.which("az") or "az")


def version_azure_cli():
    """Devuelve la version de Azure CLI como tupla (mayor, menor, parche) o None."""
    codigo, salida = capturar_real([*az_cmd(), "version", "--output", "json"])
    if codigo != 0:
        return None
    try:
        datos = json.loads(salida)
        partes = [int(x) for x in str(datos.get("azure-cli", "0")).split(".")[:3]]
        while len(partes) < 3:
            partes.append(0)
        return tuple(partes)
    except (json.JSONDecodeError, ValueError):
        return None


# Regiones preferidas cuando la suscripcion solo permite unas pocas (estudiante)
PREFERENCIA_REGIONES = [
    "centralus", "eastus2", "westus2", "southcentralus", "westus3", "northcentralus",
    "westus", "eastus", "northeurope", "westeurope", "uksouth", "germanywestcentral",
    "francecentral", "switzerlandnorth", "norwayeast", "polandcentral", "spaincentral",
    "brazilsouth", "southafricanorth", "southeastasia", "eastasia", "centralindia",
    "japaneast", "koreacentral", "australiaeast", "chilecentral",
]


def regiones_permitidas():
    """
    Lee la directiva 'Allowed resource deployment regions' que Azure asigna a las
    suscripciones de estudiante. Devuelve la lista blanca de regiones, o [] si no
    existe ninguna directiva de ese tipo (suscripciones normales).
    """
    codigo, salida = capturar([*az_cmd(), "policy", "assignment", "list",
                               "--output", "json", "--only-show-errors"])
    if codigo != 0 or not salida.strip():
        return []
    asignaciones = json_tolerante(salida)
    if not isinstance(asignaciones, list):
        return []
    regiones = []
    for asignacion in asignaciones:
        parametros = asignacion.get("parameters") or {}
        for clave, valor in parametros.items():
            # la directiva usa el parametro listOfAllowedLocations (o nombres parecidos)
            if "location" in clave.lower() and isinstance(valor, dict):
                lista = valor.get("value")
                if isinstance(lista, list):
                    for region in lista:
                        if isinstance(region, str) and region not in regiones:
                            regiones.append(region)
    return regiones


def elegir_region(region_deseada, permitidas):
    """
    Decide la region de despliegue. Devuelve (region_elegida, lista_de_intentos).
    Si hay directiva de estudiante, garantiza que la region elegida este permitida;
    la lista de intentos ordena el resto de regiones permitidas para reintentos.
    """
    if not permitidas:
        return region_deseada, [region_deseada]
    if region_deseada in permitidas:
        primera = region_deseada
    else:
        primera = next((r for r in PREFERENCIA_REGIONES if r in permitidas), permitidas[0])
    resto = [r for r in PREFERENCIA_REGIONES if r in permitidas and r != primera]
    resto += [r for r in permitidas if r != primera and r not in resto]
    return primera, [primera] + resto


def existe_comando(nombre):
    return shutil.which(nombre) is not None


def esperar(segundos, motivo):
    info("%s (espero %d s)..." % (motivo, segundos))
    if not DRY:
        time.sleep(segundos)


# --------------------------------------------------------------------------- configuracion local

def cargar_config():
    if os.path.isfile(ARCHIVO_CONFIG):
        try:
            with open(ARCHIVO_CONFIG, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            aviso("El archivo de config local esta danado; creo uno nuevo.")
    return {}


def guardar_config(cfg):
    if DRY:
        return  # el modo simulado nunca modifica la configuracion local
    os.makedirs(CARPETA_CONFIG, exist_ok=True)
    with open(ARCHIVO_CONFIG, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)


def clave_fuerte(longitud=28):
    """Genera una clave que cumple la politica de Azure PostgreSQL (mayuscula, minuscula, numero, simbolo)."""
    random.seed()  # fuerza entropia del sistema
    while True:
        base = "".join(random.choice(string.ascii_letters + string.digits) for _ in range(longitud - 2))
        candidata = base + random.choice("!#$@") + random.choice(string.digits)
        if (any(c.islower() for c in candidata) and any(c.isupper() for c in candidata)
                and any(c.isdigit() for c in candidata)):
            return candidata


def sufijo_aleatorio():
    random.seed()
    return "".join(random.choice("abcdefghijklmnopqrstuvwxyz0123456789") for _ in range(6))


# --------------------------------------------------------------------------- herramientas locales

def version_java_mayor():
    """Devuelve la version mayor del JDK (17, 21, 25...) o None si no hay JDK compilador."""
    if not existe_comando("javac"):
        return None
    # javac/java escriben la version en stderr; capturar_real une stdout y stderr
    codigo, texto = capturar_real(["javac", "-version"])
    codigo2, salida_java = capturar_real(["java", "-version"])
    texto += salida_java
    m = re.search(r'version "(\d+)', texto)
    if m:
        return int(m.group(1))
    m = re.search(r'version "1\.(\d+)', texto)
    return int(m.group(1)) if m else None


def _java_home_valido(ruta):
    """Un JDK/JRE valido tiene bin/java (y en Windows, java.exe)."""
    if not ruta:
        return False
    ejecutable = "java.exe" if ES_WINDOWS else "java"
    return os.path.isfile(os.path.join(ruta, "bin", ejecutable))


def _version_del_jdk(ruta):
    """Lee la version mayor desde el archivo 'release' del JDK; 0 si no se puede."""
    archivo_release = os.path.join(ruta, "release")
    try:
        with open(archivo_release, "r", encoding="utf-8", errors="replace") as f:
            m = re.search(r'JAVA_VERSION="(\d+)', f.read())
            return int(m.group(1)) if m else 0
    except OSError:
        return 0


def resolver_java_home():
    """
    Encuentra un JAVA_HOME valido (carpeta real del JDK con bin/java).
    Orden de busqueda:
      1) la variable JAVA_HOME, si ya apunta a un JDK valido;
      2) el destino real de javac/java en el PATH (resuelve symlinks tipo
         'Oracle javapath' que NO son un JDK valido por si mismos);
      3) las carpetas tipicas de instalacion (Oracle, Temurin, Microsoft, Corretto, Zulu).
    Devuelve la ruta del JDK preferiblemente con compilador (javac) y version >= 17.
    """
    candidatos = []

    actual = os.environ.get("JAVA_HOME")
    if actual and _java_home_valido(actual):
        candidatos.append(os.path.normpath(actual))
    elif actual:
        aviso("La variable JAVA_HOME apunta a una ruta invalida (%s); busco el JDK real." % actual)

    # destino real de los ejecutables del PATH (resuelve symlinks / shims de Oracle)
    for herramienta in ("javac", "java"):
        ruta = shutil.which(herramienta)
        if ruta:
            home = os.path.dirname(os.path.dirname(os.path.realpath(ruta)))
            if _java_home_valido(home) and home not in candidatos:
                candidatos.append(home)

    # carpetas tipicas de instalacion
    if ES_WINDOWS:
        pf = os.environ.get("ProgramFiles", r"C:\Program Files")
        pf86 = os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")
        raices = [os.path.join(pf, "Java"),
                  os.path.join(pf, "Eclipse Adoptium"),
                  os.path.join(pf, "Microsoft"),
                  os.path.join(pf, "Amazon Corretto"),
                  os.path.join(pf, "Zulu"),
                  os.path.join(pf86, "Java")]
    else:
        raices = ["/usr/lib/jvm", "/opt/java", "/Library/Java/JavaVirtualMachines"]
    for raiz in raices:
        if not os.path.isdir(raiz):
            continue
        for nombre in sorted(os.listdir(raiz), reverse=True):
            home = os.path.join(raiz, nombre)
            # macOS: los JDK cuelgan de Contents/Home
            if not ES_WINDOWS and os.path.isfile(os.path.join(home, "Contents", "Home", "bin", "java")):
                home = os.path.join(home, "Contents", "Home")
            if _java_home_valido(home) and home not in candidatos:
                candidatos.append(home)

    if not candidatos:
        return None

    # prioridad: JDK (con javac) version >=17, luego el de mayor version
    def clave(home):
        tiene_javac = os.path.isfile(os.path.join(home, "bin",
                                                   "javac.exe" if ES_WINDOWS else "javac"))
        version = _version_del_jdk(home)
        return (1 if tiene_javac and version >= 17 else 0, version)

    return max(candidatos, key=clave)


def buscar_maven():
    """Devuelve la ruta de mvn; si no existe, descarga Maven 3.9.9 a .tools (igual que el generador)."""
    mvn = shutil.which("mvn")
    if mvn:
        return mvn
    nombre = "mvn.cmd" if ES_WINDOWS else "mvn"
    local = os.path.join(TOOLS, "apache-maven-%s" % MAVEN_VERSION, "bin", nombre)
    if os.path.isfile(local):
        if not ES_WINDOWS:
            # el ZIP de Maven no conserva permisos; garantiza el bit de ejecucion
            for script in ("mvn", "mvnDebug"):
                ruta_script = os.path.join(TOOLS, "apache-maven-%s" % MAVEN_VERSION, "bin", script)
                if os.path.isfile(ruta_script):
                    os.chmod(ruta_script, 0o755)
        return local
    info("Maven no esta instalado; lo descargo a .tools (unos 10 MB)...")
    if DRY:
        return local
    os.makedirs(TOOLS, exist_ok=True)
    zip_ruta = os.path.join(TOOLS, "maven.zip")
    urllib.request.urlretrieve(MAVEN_URL, zip_ruta)
    with zipfile.ZipFile(zip_ruta) as z:
        z.extractall(TOOLS)
    os.remove(zip_ruta)
    if not os.path.isfile(local):
        fatal("No pude instalar Maven automaticamente. Instala Maven desde https://maven.apache.org")
    if not ES_WINDOWS:
        # el ZIP de Maven no conserva permisos de ejecucion en Linux/macOS
        for script in ("mvn", "mvnDebug"):
            ruta_script = os.path.join(TOOLS, "apache-maven-%s" % MAVEN_VERSION, "bin", script)
            if os.path.isfile(ruta_script):
                os.chmod(ruta_script, 0o755)
    ok("Maven %s listo en .tools" % MAVEN_VERSION)
    return local


def actualizar_gitignore():
    """Agrega las carpetas de trabajo del despliegue al .gitignore (contienen secretos)."""
    if DRY:
        return
    ruta = os.path.join(RAIZ_PROYECTO, ".gitignore")
    lineas = []
    if os.path.isfile(ruta):
        with open(ruta, "r", encoding="utf-8") as f:
            lineas = f.read().splitlines()
    agregados = []
    for entrada in (os.path.basename(CARPETA_CONFIG) + "/", "backend/src/main/resources/static/"):
        if entrada not in lineas:
            lineas.append(entrada)
            agregados.append(entrada)
    if agregados:
        with open(ruta, "w", encoding="utf-8") as f:
            f.write("\n".join(lineas).rstrip() + "\n")
        ok(".gitignore actualizado (%s)." % ", ".join(agregados))


def comprobar_requisitos():
    titulo("PASO 1/7 - Verificando herramientas necesarias")
    falta = []

    if not os.path.isdir(BACKEND) or not os.path.isdir(FRONTEND) or not os.path.isdir(DATABASE):
        fatal("Este script debe estar en la carpeta raiz del proyecto (junto a backend/, frontend/ y database/).\n"
              "       Carpeta actual: %s" % RAIZ_PROYECTO)
    ok("Carpeta del proyecto reconocida: %s" % RAIZ_PROYECTO)

    # Azure CLI
    if not existe_comando("az"):
        falta.append("Azure CLI: descargalo de https://aka.ms/installazurecliwindows "
                     "(instalador MSI para Windows).")
    else:
        ver = version_azure_cli()
        ok("Azure CLI instalado" + (" (version %s)" % ".".join(map(str, ver)) if ver else ""))

    # JDK (necesita javac, no solo JRE)
    java_mayor = version_java_mayor()
    if java_mayor is None:
        falta.append("JDK 17 o superior (incluye javac): https://adoptium.net/temurin/releases/ "
                     "(elige Windows x64, JDK 21 LTS, .msi).")
    elif java_mayor < 17:
        falta.append("El JDK detectado es la version %d y el proyecto necesita 17 o superior. "
                     "Instala JDK 21 LTS desde https://adoptium.net/temurin/releases/" % java_mayor)
    else:
        ok("JDK version %d detectado" % java_mayor)
        java_home = resolver_java_home()
        if java_home:
            info("JAVA_HOME que se usara con Maven: %s" % java_home)
        else:
            aviso("No se pudo resolver un JAVA_HOME valido; si Maven falla, instala JDK 17/21 "
                  "desde https://adoptium.net/temurin/releases/ (.msi).")

    # Node.js
    if not existe_comando("node") or not existe_comando("npm"):
        falta.append("Node.js 18+ (incluye npm): https://nodejs.org/es/download (version LTS para Windows).")
    else:
        codigo, salida = capturar_real(["node", "--version"])
        encontrado = re.search(r"v?(\d+)", salida)
        mayor = int(encontrado.group(1)) if encontrado else 0
        if mayor < 18:
            falta.append("Node.js detectado v%d, necesita 18 o superior: https://nodejs.org" % mayor)
        else:
            ok("Node.js %s detectado" % salida.strip())

    # Python (ya esta corriendo)
    ok("Python %d.%d" % (sys.version_info[0], sys.version_info[1]))

    if falta:
        error("Faltan herramientas obligatorias:")
        for f in falta:
            print("        - " + f)
        fatal("Instala lo que falta y vuelve a ejecutar el programa.")
    return java_mayor


# --------------------------------------------------------------------------- Azure: login y suscripcion

def asegurar_login():
    titulo("PASO 2/7 - Inicio de sesion en Azure (cuenta estudiantil)")
    codigo, _ = capturar([*az_cmd(), "account", "show", "--only-show-errors"])
    if codigo == 0:
        ok("Ya habia una sesion de Azure iniciada.")
        return
    info("Se abrira el navegador para iniciar sesion. Usa tu cuenta estudiantil "
         "(la misma con la que activaste Azure for Students).")
    rc = ejecutar([*az_cmd(), "login", "--only-show-errors"])
    if rc != 0:
        fatal("No se pudo iniciar sesion en Azure. Revisa tus credenciales e intenta de nuevo.")
    ok("Sesion iniciada.")


def elegir_suscripcion(suscripcion_indicada=None):
    codigo, salida = capturar([*az_cmd(), "account", "list", "--only-show-errors", "--output", "json"])
    if codigo != 0:
        fatal("No pude leer las suscripciones de Azure.")
    try:
        cuentas = json.loads(salida)
    except json.JSONDecodeError:
        cuentas = []
    if not cuentas:
        if DRY:
            info("Modo simulado: uso una suscripcion de ejemplo 'Azure for Students'.")
            return {"id": "00000000-0000-0000-0000-000000000000", "name": "Azure for Students (simulada)"}
        fatal("La cuenta no tiene ninguna suscripcion. Activa Azure for Students en "
              "https://azure.microsoft.com/free/students/ (sin tarjeta de credito, incluye USD 100 de credito).")

    elegida = None
    if suscripcion_indicada:
        clave = suscripcion_indicada.lower()
        for c in cuentas:
            if c.get("id", "").lower() == clave or c.get("name", "").lower() == clave:
                elegida = c
                break
        if not elegida:
            fatal("No existe una suscripcion que coincida con '%s'." % suscripcion_indicada)
    elif len(cuentas) == 1:
        elegida = cuentas[0]
    else:
        # prefiere la suscripcion de estudiante
        for c in cuentas:
            nombre = (c.get("name") or "").lower()
            if "student" in nombre or "estudiante" in nombre:
                elegida = c
                break
        if elegida is None:
            print("\n  Hay varias suscripciones. Elige una:")
            for i, c in enumerate(cuentas, 1):
                print("    %d) %s  (%s)" % (i, c.get("name"), c.get("id")))
            try:
                idx = int(input("  Numero: ").strip()) - 1
                elegida = cuentas[idx]
            except (ValueError, IndexError, EOFError):
                aviso("Respuesta invalida; uso la primera suscripcion.")
                elegida = cuentas[0]

    ejecutar([*az_cmd(), "account", "set", "--subscription", elegida["id"], "--only-show-errors"])
    ok("Suscripcion activa: %s" % elegida.get("name"))
    return elegida


def detectar_runtime_java(java_local):
    """Elige el runtime Java de Azure mas nuevo que soporte tanto Azure como el JDK local."""
    codigo, salida = capturar([*az_cmd(), "webapp", "list-runtimes", "--os", "linux",
                               "--runtime", "java", "--output", "json", "--only-show-errors"])
    versiones = set()
    if codigo == 0 and salida.strip():
        try:
            datos = json.loads(salida)
            for item in datos:
                texto = item.get("config", "") if isinstance(item, dict) else str(item)
                m = re.search(r"JAVA[|:](\d+)", texto)
                if m:
                    versiones.add(int(m.group(1)))
        except json.JSONDecodeError:
            pass
    for v in (25, 21, 17):
        if v in versiones and v <= java_local:
            return "JAVA:%d-java%d" % (v, v), v
    # sin poder consultar (p.ej. dry-run o CLI viejo): usa 21 si el JDK local alcanza, si no 17
    v = 21 if java_local >= 21 else (java_local if java_local >= 17 else 17)
    if versiones and v not in versiones and 17 in versiones:
        v = 17
    return "JAVA:%d-java%d" % (v, v), v


def recurso_existe(cmd_show):
    if DRY:
        return False  # en simulado se muestra el plan de creacion completo
    codigo, _ = capturar(cmd_show + ["--only-show-errors"])
    return codigo == 0


# --------------------------------------------------------------------------- archivos que se agregan al backend

SPA_CONTROLLER = """package com.uagrm.activos.web;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Agregado por desplegar_azure.py.
 * Sirve la aplicacion Angular (SPA) alojada en src/main/resources/static.
 * Las rutas del frontend se reenvian a index.html; la API (/api/**) y los
 * archivos con extension (.js, .css, .png...) no se tocan.
 */
@Controller
public class SpaController {

    @GetMapping({
        "/",
        "/{seg:(?!api)[a-zA-Z0-9-]+}",
        "/{seg:(?!api)[a-zA-Z0-9-]+}/**"
    })
    public String forwardAngular() {
        return "forward:/index.html";
    }
}
"""

SPA_SECURITY = """package com.uagrm.activos.web;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Agregado por desplegar_azure.py.
 * Permite el acceso publico a los archivos estaticos y a las rutas del
 * frontend Angular. La API sigue protegida por el SecurityConfig original
 * (cadena de seguridad por defecto, con JWT), porque todas sus rutas
 * empiezan con /api/** y quedan excluidas de esta cadena.
 */
@Configuration
public class SpaSecurityConfig {

    @Bean
    @Order(0)
    public SecurityFilterChain spaFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher(
                "/",
                "/index.html",
                "/favicon.ico",
                "/robots.txt",
                "/manifest.webmanifest",
                "/manifest.json",
                "/*.js", "/*.css", "/*.ico", "/*.png", "/*.jpg", "/*.jpeg",
                "/*.gif", "/*.svg", "/*.webp", "/*.woff", "/*.woff2",
                "/*.ttf", "/*.eot", "/*.map",
                "/assets/**",
                "/media/**",
                "/icons/**",
                "/{seg:(?!api)[a-zA-Z0-9-]+}",
                "/{seg:(?!api)[a-zA-Z0-9-]+}/**"
            )
            .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
            .csrf(csrf -> csrf.disable());
        return http.build();
    }
}
"""

ENV_FRONTEND = """// Generado por desplegar_azure.py: el frontend se sirve desde el mismo
// dominio que el backend (App Service), por eso la API es una ruta relativa.
export const environment = {
  production: true,
  apiUrl: '/api'
};
"""


def preparar_backend(java_objetivo):
    titulo("PASO 4/7 - Preparando el backend Spring Boot")
    if DRY:
        info("Modo simulado: ajustaria pom.xml a Java %d y agregaria SpaController/SpaSecurityConfig."
             % java_objetivo)
        return
    # 1) ajustar la version de Java del pom (el proyecto viene con Java 25; Azure puede ofrecer 17/21/25)
    pom = os.path.join(BACKEND, "pom.xml")
    with open(pom, "r", encoding="utf-8") as f:
        contenido = f.read()
    m = re.search(r"<java.version>(\d+)</java.version>", contenido)
    version_actual = int(m.group(1)) if m else None
    if version_actual != java_objetivo:
        if not os.path.isfile(pom + ".azure-bak"):
            shutil.copy2(pom, pom + ".azure-bak")
        contenido = re.sub(r"<java.version>\d+</java.version>",
                           "<java.version>%d</java.version>" % java_objetivo, contenido)
        with open(pom, "w", encoding="utf-8") as f:
            f.write(contenido)
        ok("pom.xml ajustado de Java %s a Java %d (copia original en pom.xml.azure-bak)"
           % (version_actual, java_objetivo))
    else:
        ok("pom.xml ya apunta a Java %d" % java_objetivo)

    # 2) agregar (o reescribir) las clases de soporte SPA
    paquete_web = os.path.join(BACKEND, "src", "main", "java", "com", "uagrm", "activos", "web")
    os.makedirs(paquete_web, exist_ok=True)
    with open(os.path.join(paquete_web, "SpaController.java"), "w", encoding="utf-8") as f:
        f.write(SPA_CONTROLLER)
    with open(os.path.join(paquete_web, "SpaSecurityConfig.java"), "w", encoding="utf-8") as f:
        f.write(SPA_SECURITY)
    ok("Clases SpaController y SpaSecurityConfig agregadas (servir Angular sin CORS).")


def preparar_frontend():
    titulo("PASO 3/7 - Preparando y compilando el frontend Angular")
    if DRY:
        info("Modo simulado: cambiaria environment.ts a '/api', ejecutaria 'npm ci' y 'npm run build', "
             "y copiaria dist/ a backend/src/main/resources/static.")
        return
    # 1) apuntar la API a ruta relativa (mismo origen)
    env_prod = os.path.join(FRONTEND, "src", "environments", "environment.ts")
    if not os.path.isfile(env_prod + ".azure-bak"):
        shutil.copy2(env_prod, env_prod + ".azure-bak")
    with open(env_prod, "w", encoding="utf-8") as f:
        f.write(ENV_FRONTEND)
    ok("environment.ts configurado con apiUrl relativa '/api'.")

    # 2) dependencias de Node
    npm = shutil.which("npm")
    if not npm:
        fatal("No se encontro npm en el PATH.")
    npm_cmd = comando_windows(npm)
    if os.path.isdir(os.path.join(FRONTEND, "node_modules")):
        info("node_modules ya existe; omito 'npm ci' (borra la carpeta si quieres reinstalar).")
    else:
        info("Instalando dependencias de Node (npm ci, puede tardar varios minutos)...")
        rc = ejecutar(npm_cmd + ["ci", "--no-audit", "--no-fund"], cwd=FRONTEND)
        if rc != 0:
            aviso("'npm ci' fallo; intento con 'npm install'...")
            rc = ejecutar(npm_cmd + ["install", "--no-audit", "--no-fund"], cwd=FRONTEND)
            if rc != 0:
                fatal("No se pudieron instalar las dependencias del frontend.")
        ok("Dependencias de Node instaladas.")

    # 3) build de produccion
    info("Compilando Angular (ng build)...")
    rc = ejecutar(npm_cmd + ["run", "build"], cwd=FRONTEND)
    if rc != 0:
        fatal("Falló la compilacion de Angular.")

    # 4) localizar el resultado (Angular 18: dist/frontend/browser/index.html)
    candidatos = glob.glob(os.path.join(FRONTEND, "dist", "**", "index.html"), recursive=True)
    if not candidatos:
        fatal("No encontre index.html en dist/ tras compilar Angular.")
    dist_browser = os.path.dirname(candidatos[0])
    ok("Build de Angular listo en: %s" % os.path.relpath(dist_browser, RAIZ_PROYECTO))

    # 5) copiar el build a los recursos estaticos del backend
    static = os.path.join(BACKEND, "src", "main", "resources", "static")
    if os.path.isdir(static):
        shutil.rmtree(static)
    shutil.copytree(dist_browser, static)
    ok("Frontend copiado a backend/src/main/resources/static (se sirve dentro del JAR).")


def compilar_backend():
    titulo("PASO 5/7 - Compilando el backend con Maven")
    if DRY:
        info("Modo simulado: ejecutaria 'mvn -B -DskipTests package' y obtendria el JAR de backend/target.")
        return os.path.join(BACKEND, "target", "activos-backend-0.0.1-SNAPSHOT.jar")
    mvn = buscar_maven()
    mvn_cmd = comando_windows(mvn)
    env = os.environ.copy()
    # Maven exige un JAVA_HOME valido: lo resolvemos automaticamente aunque el
    # PATH use los shims de Oracle (javapath) o la variable JAVA_HOME este mal.
    java_home = resolver_java_home()
    if not java_home:
        fatal("No encontre ningun JDK valido para Maven. Instala JDK 17/21 desde "
              "https://adoptium.net/temurin/releases/ (instalador .msi) y vuelve a ejecutar.")
    env["JAVA_HOME"] = java_home
    env["PATH"] = os.path.join(java_home, "bin") + os.pathsep + env.get("PATH", "")
    ok("JAVA_HOME detectado: %s" % java_home)
    info("Empaquetando el JAR (mvn package -DskipTests); la primera vez descarga dependencias...")
    rc = ejecutar(mvn_cmd + ["-B", "-DskipTests", "package"], cwd=BACKEND, env=env)
    if rc != 0:
        fatal("Falló la compilacion de Maven. Revisa los mensajes de arriba.")
    jars = [j for j in glob.glob(os.path.join(BACKEND, "target", "*.jar"))
            if not j.endswith(".original")]
    if not jars:
        fatal("No se genero ningun JAR en backend/target.")
    jar = max(jars, key=os.path.getmtime)
    ok("JAR generado: %s (%.1f MB)" % (os.path.basename(jar), os.path.getsize(jar) / 1048576))
    return jar


# --------------------------------------------------------------------------- Azure: infraestructura

def crear_postgres_azure(cfg, rg, region, servidor):
    """Aprovisiona Azure Database for PostgreSQL flexible (opcion de pago con credito)."""
    # La sintaxis de PostgreSQL flexible cambio en versiones recientes de Azure CLI:
    #  - 2.87+: elimino --high-availability (la HA viene desactivada por defecto)
    #  - 2.90+: 'db show/create' usa --name para la base (antes era -d/--database-name)
    ver_cli = version_azure_cli()
    cli_nueva_ha = ver_cli is None or ver_cli >= (2, 87, 0)
    cli_nueva_db = ver_cli is None or ver_cli >= (2, 90, 0)
    flag_bd = ["--name", NOMBRE_BD] if cli_nueva_db else ["-d", NOMBRE_BD]

    # servidor PostgreSQL flexible (tarda entre 5 y 15 minutos)
    if recurso_existe([*az_cmd(), "postgres", "flexible-server", "show", "-g", rg, "-n", servidor]):
        ok("El servidor PostgreSQL %s ya existe." % servidor)
    else:
        info("Creando servidor PostgreSQL %s (SKU %s, %s GB). Esto tarda de 5 a 15 minutos..."
             % (servidor, PG_SKU, PG_STORAGE_GB))
        cmd_crear_servidor = [*az_cmd(), "postgres", "flexible-server", "create",
                              "--resource-group", rg,
                              "--name", servidor,
                              "--location", region,
                              "--admin-user", PG_USUARIO,
                              "--admin-password", cfg["pg_password"],
                              "--sku-name", PG_SKU,
                              "--tier", "Burstable",
                              "--version", PG_VERSION,
                              "--storage-size", PG_STORAGE_GB]
        if not cli_nueva_ha:
            # CLI anterior a 2.87: se declara explicitamente sin alta disponibilidad
            cmd_crear_servidor += ["--high-availability", "Disabled"]
        cmd_crear_servidor += ["--yes", "--only-show-errors"]
        rc = ejecutar(cmd_crear_servidor)
        if rc != 0:
            fatal("No se pudo crear el servidor PostgreSQL.")
        ok("Servidor PostgreSQL creado.")

    # base de datos
    codigo, _ = capturar([*az_cmd(), "postgres", "flexible-server", "db", "show",
                          "-g", rg, "-s", servidor, *flag_bd, "--only-show-errors"])
    if codigo == 0 and not DRY:
        ok("La base de datos %s ya existe." % NOMBRE_BD)
    else:
        info("Creando la base de datos %s..." % NOMBRE_BD)
        rc = ejecutar([*az_cmd(), "postgres", "flexible-server", "db", "create",
                       "-g", rg, "-s", servidor, *flag_bd, "--only-show-errors"])
        if rc != 0:
            fatal("No se pudo crear la base de datos.")
        ok("Base de datos creada.")

    # firewall: permite que los servicios de Azure (App Service) se conecten
    info("Regla de firewall 'AllowAzureServices' (0.0.0.0-0.0.0.0)...")
    if DRY or not recurso_existe([*az_cmd(), "postgres", "flexible-server", "firewall-rule", "show",
                                  "-g", rg, "-s", servidor, "-n", "AllowAzureServices"]):
        ejecutar(az_cmd() + ["postgres", "flexible-server", "firewall-rule", "create",
                  "-g", rg, "-s", servidor,
                  "--name", "AllowAzureServices",
                  "--start-ip-address", "0.0.0.0",
                  "--end-ip-address", "0.0.0.0",
                  "--only-show-errors"])
    else:
        ok("La regla de firewall AllowAzureServices ya existe.")


def crear_infraestructura(cfg, region, runtime, claves_cli=None):
    titulo("PASO 6/7 - Creando infraestructura en Azure")
    rg = cfg["resource_group"]
    servidor = cfg["pg_server"]
    plan = cfg["app_service_plan"]
    webapp = cfg["webapp"]

    # grupo de recursos
    if recurso_existe([*az_cmd(), "group", "show", "-g", rg]):
        ok("El grupo de recursos %s ya existe." % rg)
    else:
        info("Creando grupo de recursos %s en %s..." % (rg, region))
        if ejecutar([*az_cmd(), "group", "create", "-l", region, "-n", rg,
                     "--tags", "proyecto=activos-fijos-uagrm", "origen=desplegar_azure.py",
                     "--only-show-errors"]) != 0:
            fatal("No se pudo crear el grupo de recursos.")
        ok("Grupo de recursos creado.")

    if cfg.get("tipo_bd") == TIPO_BD_NEON:
        ok("Base de datos en Neon: se omiten PostgreSQL y el firewall de Azure (costo $0).")
    else:
        crear_postgres_azure(cfg, rg, region, servidor)

    # plan de App Service F1 (gratis), Linux.
    # La suscripcion de estudiante limita regiones por directiva: se intenta con cada
    # region permitida hasta que una acepte el recurso (ver regiones_permitidas()).
    if recurso_existe([*az_cmd(), "appservice", "plan", "show", "-g", rg, "-n", plan]):
        ok("El plan de App Service %s ya existe." % plan)
    else:
        intentos = cfg.get("regiones_candidatas") or [region]
        plan_creado = False
        for region_intento in intentos:
            info("Creando plan de App Service GRATUITO %s (F1, Linux) en %s..."
                 % (plan, region_intento))
            rc = ejecutar([*az_cmd(), "appservice", "plan", "create",
                           "-g", rg, "-n", plan, "--sku", APP_SERVICE_SKU, "--is-linux",
                           "--location", region_intento,
                           "--only-show-errors"])
            if rc == 0:
                cfg["region_efectiva"] = region_intento
                guardar_config(cfg)
                plan_creado = True
                break
            aviso("No se pudo crear el plan F1 en %s (directiva de regiones o sin cupo); "
                  "pruebo la siguiente region permitida." % region_intento)
        if not plan_creado:
            fatal("No se pudo crear el plan F1 en ninguna de las regiones permitidas: %s. "
                  "Revisa la directiva 'Allowed resource deployment regions' de tu suscripcion."
                  % ", ".join(intentos))
        ok("Plan F1 creado en %s (sin costo mensual)." % cfg.get("region_efectiva", region))

    # aplicacion web Java
    if recurso_existe([*az_cmd(), "webapp", "show", "-g", rg, "-n", webapp]):
        ok("La aplicacion web %s ya existe." % webapp)
    else:
        info("Creando la aplicacion web %s con runtime %s..." % (webapp, runtime))
        rc = ejecutar([*az_cmd(), "webapp", "create",
                       "-g", rg, "-p", plan, "-n", webapp,
                       "--runtime", runtime,
                       "--https-only", "true",
                       "--only-show-errors"])
        if rc != 0:
            aviso("No se pudo crear con el runtime %s; reintento con %s." % (runtime, RUNTIME_DEFECTO))
            rc = ejecutar([*az_cmd(), "webapp", "create",
                           "-g", rg, "-p", plan, "-n", webapp,
                           "--runtime", RUNTIME_DEFECTO,
                           "--https-only", "true",
                           "--only-show-errors"])
            if rc != 0:
                fatal("No se pudo crear la aplicacion web.")
        ok("Aplicacion web creada.")

    # variables de entorno de la aplicacion (segun donde viva la base de datos)
    url_web = "https://%s.azurewebsites.net" % webapp
    if cfg.get("tipo_bd") == TIPO_BD_NEON:
        datos_neon = parsear_url_postgres(cfg["neon_url"])
        jdbc = url_postgres_a_jdbc(cfg["neon_url"])
        usuario_bd, clave_bd = datos_neon["user"], datos_neon["password"]
        host_pg = datos_neon["host"]
        # keepalive de Hikari cada 2 min: evita que el pool quede con conexiones
        # colgadas cuando Neon suspende el computo por inactividad (cold start).
        extra = ["SPRING_DATASOURCE_HIKARI_KEEPALIVE_TIME=120000",
                 "SPRING_DATASOURCE_HIKARI_MAX_LIFETIME=600000"]
        if "-pooler" in host_pg:
            aviso("La cadena de Neon usa el POOLER (PgBouncer). Funciona, pero para "
                  "Spring Boot es mejor la conexion DIRECTA (sin '-pooler'): en la consola "
                  "de Neon, 'Connection string' -> version directa.")
            # PgBouncer en modo transaccion no siempre admite sentencias preparadas
            # del lado del servidor: se desactivan para evitar errores intermittent.
            extra.append("SPRING_DATASOURCE_HIKARI_DATA_SOURCE_PROPERTIES_PREPARE_THRESHOLD=0")
    else:
        host_pg = "%s.postgres.database.azure.com" % servidor
        jdbc = ("jdbc:postgresql://%s:5432/%s?sslmode=require" % (host_pg, NOMBRE_BD))
        usuario_bd, clave_bd = PG_USUARIO, cfg["pg_password"]
        extra = []
    # Carpetas escribibles del contenedor de App Service: por defecto el backend
    # usa /home/user/... (ruta de Linux de escritorio) y en Azure NO existe, asi
    # que los respaldos, las fotos de inventario y la bitacora en archivo fallaban.
    extra += ["APP_ARCHIVOS_CARPETA=/home/site/wwwroot/uploads",
              "APP_RESPALDOS_CARPETA=/home/site/wwwroot/respaldos",
              "APP_AUDITORIA_ARCHIVO=/home/site/wwwroot/logs/auditoria_sp3.log",
              # URL publica del backend: la usan las pasarelas para armar el
              # webhook y las URLs de retorno. Sin esto, Mercado Pago / PayPal /
              # Stripe / QR avian a localhost y el pago nunca se confirma.
              "APP_URL_PUBLICA=%s" % url_web]
    # Claves de la IA (Groq / Gemini): sin ellas el asistente queda en modo guiado.
    ajustes_ia_app = ajustes_ia(claves_cli)
    extra += ajustes_ia_app
    # Pasarela de pagos real: sin credenciales el sistema avisa y no simula.
    ajustes_pagos_app = ajustes_pagos()
    extra += ajustes_pagos_app
    info("Configurando variables de entorno (conexion a BD, JWT, CORS, rutas, IA y pagos)...")
    rc_settings = ejecutar([*az_cmd(), "webapp", "config", "appsettings", "set",
                            "-g", rg, "-n", webapp,
                            "--settings",
                            "SPRING_DATASOURCE_URL=%s" % jdbc,
                            "SPRING_DATASOURCE_USERNAME=%s" % usuario_bd,
                            "SPRING_DATASOURCE_PASSWORD=%s" % clave_bd,
                            "APP_JWT_SECRET=%s" % cfg["jwt_secret"],
                            "APP_CORS_ORIGIN=%s" % url_web,
                            *extra,
                            "--only-show-errors",
                            "--output", "none"])
    if ajustes_ia_app:
        informar_ia(ajustes_ia_app)
    informar_pagos(ajustes_pagos_app)
    # Verificacion: leer de nuevo la URL de conexion para confirmar que no quedo
    # truncada (antes un '&' sin escapar partia el comando y la dejaba en null).
    # No se usa --query JMESPath: ese argumento lleva espacios y '|', Python lo
    # entrecomilla y la regla de comillas de 'cmd /c' lo corrompe (se elimina la
    # ultima comilla de la linea, que deja de ser la de la ruta de az.CMD).
    # Se pide JSON y se filtra aqui, igual que en la deteccion de regiones.
    if not DRY and rc_settings == 0:
        rc_lista, salida_lista = capturar([*az_cmd(), "webapp", "config", "appsettings",
                                           "list", "-g", rg, "-n", webapp,
                                           "--output", "json", "--only-show-errors"])
        valor = ""
        ajustes = json_tolerante(salida_lista)
        if isinstance(ajustes, list):
            for item in ajustes:
                if isinstance(item, dict) and item.get("name") == "SPRING_DATASOURCE_URL":
                    valor = item.get("value") or ""
                    break
        host_esperado = host_pg
        if rc_lista != 0 or host_esperado not in valor:
            fatal("La variable SPRING_DATASOURCE_URL no se grabo correctamente en App "
                  "Service (se esperaba el host %s). Revisa caracteres especiales en la "
                  "cadena de conexion." % host_esperado)
        ok("Variables de entorno verificadas en App Service (host de BD: %s)." % host_esperado)

    # logs de aplicacion habilitados para 'az webapp log tail'
    ejecutar([*az_cmd(), "webapp", "log", "config",
              "-g", rg, "-n", webapp,
              "--application-logging", "filesystem",
              "--level", "information",
              "--detailed-error-messages", "true",
              "--docker-container-logging", "filesystem",
              "--only-show-errors",
              "--output", "none"])

    cfg["pg_host"] = host_pg
    cfg["webapp_url"] = url_web
    guardar_config(cfg)
    return host_pg, url_web


# --------------------------------------------------------------------------- Neon (PostgreSQL gratis)

SQLRUNNER_PACKAGE = """{
  "name": "sqlrunner-neon",
  "version": "1.0.0",
  "private": true,
  "dependencies": { "pg": "^8.13.1" }
}
"""

SQLRUNNER_JS = """// Ejecutor de scripts SQL para Neon (o cualquier PostgreSQL) usando node-postgres.
// Lo genera desplegar_azure.py; recibe la cadena de conexion por DATABASE_URL.
//
// IMPORTANTE: cada sentencia se envia por separado. Antes el script entero
// viajaba en una sola llamada: PostgreSQL lo ejecutaba dentro de una transaccion
// implicita y, si UNA sentencia fallaba (por ejemplo una partida presupuestaria
// que aun no existe), se revertia TODO el archivo y la aplicacion se quedaba
// sin datos. Ahora cada sentencia se confirma por separado y los fallos se
// listan uno a uno, sin tirar la carga completa.
//
//   node ejecutar_sql.js archivo.sql        -> ejecuta el script sentencia a sentencia
//   node ejecutar_sql.js --consulta "SQL"   -> imprime el valor de la primera fila
const { Client } = require('pg');
const fs = require('fs');

const url = process.env.DATABASE_URL;
const archivo = process.argv[2];
if (!url || !archivo) {
  console.error('Uso: DATABASE_URL=... node ejecutar_sql.js archivo.sql');
  console.error('      DATABASE_URL=... node ejecutar_sql.js --consulta "SELECT ..."');
  process.exit(2);
}
// Neon exige SSL; para pruebas locales sin SSL se desactiva automaticamente.
const ssl = /neon\\.tech/i.test(url) ? { rejectUnauthorized: true } : false;

// Divide el script en sentencias respetando comillas simples y bloques $$ ... $$.
function dividir(sql) {
  const partes = [];
  let actual = '';
  let tagDolar = null;
  let comilla = false;
  let comentario = false;
  for (let i = 0; i < sql.length; i++) {
    const c = sql.charAt(i);
    const siguiente = (i + 1 < sql.length) ? sql.charAt(i + 1) : '';
    if (comentario) {
      actual += c;
      if (c === '\\n') comentario = false;
      continue;
    }
    if (!comilla && tagDolar === null && c === '-' && siguiente === '-') {
      comentario = true;
      actual += c;
      continue;
    }
    if (c === "'" && tagDolar === null) {
      comilla = !comilla;
      actual += c;
      continue;
    }
    if (!comilla) {
      const m = /^\\$[A-Za-z0-9_]*\\$/.exec(sql.substring(i));
      if (m && m[0].length > 0) {
        const token = m[0];
        actual += token;
        i += token.length - 1;
        if (tagDolar === null) tagDolar = token;
        else if (tagDolar === token) tagDolar = null;
        continue;
      }
    }
    if (c === ';' && !comilla && tagDolar === null) {
      if (actual.trim() !== '') partes.push(actual.trim());
      actual = '';
      continue;
    }
    actual += c;
  }
  if (actual.trim() !== '') partes.push(actual.trim());
  return partes;
}

(async () => {
  const cliente = new Client({ connectionString: url, ssl });
  await cliente.connect();
  try {
    if (archivo === '--consulta') {
      const sql = process.argv[3] || '';
      const r = await cliente.query(sql);
      if (r.rows && r.rows.length > 0) {
        const valores = Object.values(r.rows[0]);
        console.log(valores.length === 1 ? String(valores[0]) : JSON.stringify(r.rows[0]));
      } else {
        console.log('');
      }
      await cliente.end();
      return;
    }

    const sql = fs.readFileSync(archivo, 'utf8');
    const sentencias = dividir(sql);
    let ok = 0;
    const fallos = [];
    for (let i = 0; i < sentencias.length; i++) {
      const s = sentencias[i];
      if (s.trim() === '') continue;
      try {
        await cliente.query(s);
        ok++;
      } catch (e) {
        fallos.push({ n: i + 1, msg: (e && e.message) ? e.message : String(e), sql: s.substring(0, 160) });
      }
    }
    await cliente.end();
    console.log('SQL: ' + ok + ' sentencias aplicadas, ' + fallos.length + ' con error.');
    if (fallos.length > 0) {
      fallos.slice(0, 10).forEach(f => {
        console.error('  ERROR stmt #' + f.n + ': ' + f.msg);
        console.error('        ' + f.sql.replace(/\\s+/g, ' '));
      });
      if (fallos.length > 10) console.error('  ... y ' + (fallos.length - 10) + ' mas.');
      process.exit(1);
    }
    console.log('SQL OK: ' + archivo);
  } catch (e) {
    console.error('SQL ERROR: ' + (e && e.message ? e.message : e));
    process.exit(1);
  }
})().catch((e) => {
  console.error('SQL ERROR: ' + (e && e.message ? e.message : e));
  process.exit(1);
});
"""


def parsear_url_postgres(url):
    """Convierte una cadena postgresql://usuario:clave@host:puerto/base?params en un dict."""
    from urllib.parse import urlparse, unquote
    parseada = urlparse(url.strip())
    if parseada.scheme not in ("postgres", "postgresql") or not parseada.hostname or not parseada.username:
        fatal("La cadena de conexion no tiene el formato esperado. Ejemplo:\n"
              "       postgresql://usuario:clave@ep-xxxx.us-east-2.aws.neon.tech/neondb?sslmode=require")
    return {
        "user": unquote(parseada.username),
        "password": unquote(parseada.password or ""),
        "host": parseada.hostname,
        "port": parseada.port or 5432,
        "database": parseada.path.lstrip("/"),
        "query": parseada.query,
    }


def url_postgres_a_jdbc(url):
    """
    Convierte la cadena de Neon al formato SPRING_DATASOURCE_URL de Spring Boot.
    Solo conserva 'sslmode' (pgjdbc lo entiende) y descarta el resto de parametros
    libpq, en especial 'channel_binding', que ademas introduce un '&' que rompe
    la linea de comandos de Windows (cmd interpreta & como separador de comandos).
    El resultado lleva un unico parametro, sin '&'.
    """
    datos = parsear_url_postgres(url)
    sslmode = "require"
    for parametro in datos["query"].split("&"):
        if parametro.startswith("sslmode="):
            valor = parametro.split("=", 1)[1].strip()
            if valor in ("require", "verify-ca", "verify-full"):
                sslmode = valor
            break
    return ("jdbc:postgresql://%s:%s/%s?sslmode=%s"
            % (datos["host"], datos["port"], datos["database"], sslmode))


def leer_config_ia():
    """Lee ia_config.json (el archivo que crea configurar_ia.bat). Nunca se copia al JAR."""
    ruta = os.path.join(RAIZ_PROYECTO, "ia_config.json")
    if not os.path.isfile(ruta):
        return {}
    try:
        with open(ruta, encoding="utf-8") as f:
            datos = json.load(f)
        return datos if isinstance(datos, dict) else {}
    except Exception:
        return {}


def ajustes_ia(claves_cli=None):
    """
    Variables de entorno de la IA para App Service.

    Prioridad: --groq-clave/--gemini-clave > variable de entorno de Windows >
    ia_config.json del proyecto. La clave se guarda en App Service (cifrada en
    reposo por Azure) y NO se escribe en el repositorio ni se imprime entera.
    """
    archivo = leer_config_ia()
    cli = claves_cli or {}
    groq = (cli.get("groq") or os.environ.get("GROQ_API_KEY")
            or archivo.get("groq_api_key") or "")
    gemini = (cli.get("gemini") or os.environ.get("GEMINI_API_KEY")
              or archivo.get("gemini_api_key") or "")
    modelo_groq = os.environ.get("GROQ_MODEL") or archivo.get("groq_modelo") or ""
    modelo_gemini = os.environ.get("GEMINI_MODEL") or archivo.get("gemini_modelo") or ""
    ajustes = []
    if groq and groq.strip():
        ajustes.append("GROQ_API_KEY=%s" % groq.strip())
    if gemini and gemini.strip():
        ajustes.append("GEMINI_API_KEY=%s" % gemini.strip())
    if modelo_groq and modelo_groq.strip():
        ajustes.append("GROQ_MODEL=%s" % modelo_groq.strip())
    if modelo_gemini and modelo_gemini.strip():
        ajustes.append("GEMINI_MODEL=%s" % modelo_gemini.strip())
    return ajustes


def leer_pasarelas_env():
    """
    Lee pasarelas.env (el archivo que escribe configurar_pasarelas.py).

    Es el mismo archivo que lee el backend al arrancar, asi que la pasarela
    que funciona en local funciona tambien en Azure sin tener que hacer
    'setx' ni reiniciar la terminal. Prioridad: variable de entorno de Windows
    > archivo pasarelas.env.
    """
    datos = {}
    for carpeta in (RAIZ_PROYECTO, os.path.dirname(RAIZ_PROYECTO)):
        ruta = os.path.join(carpeta, "pasarelas.env")
        if not os.path.isfile(ruta):
            continue
        try:
            with open(ruta, encoding="utf-8") as f:
                for linea in f:
                    linea = linea.strip()
                    if not linea or linea.startswith("#") or "=" not in linea:
                        continue
                    clave, valor = linea.split("=", 1)
                    clave = clave.strip()
                    valor = valor.strip().strip('"').strip("'")
                    if clave and valor:
                        datos[clave] = valor
        except Exception:
            continue
    return datos


def ajustes_pagos():
    """
    Variables de entorno de la pasarela de pagos REAL.

    Se leen del archivo pasarelas.env y del entorno de Windows
    (MERCADOPAGO_ACCESS_TOKEN, PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET,
    MERCADOPAGO_WEBHOOK_SECRET, APP_PAGOS_PROVEEDOR...). Si no hay ninguna,
    el backend queda en modo "sin pasarela": avisa con claridad y NO simula los
    pagos.
    """
    archivo = leer_pasarelas_env()
    ajustes = []

    def valor_de(nombre):
        # El entorno de Windows manda; el archivo es el respaldo (asi funciona
        # sin tener que cerrar y abrir la terminal despues del 'setx').
        return (os.environ.get(nombre) or archivo.get(nombre) or "").strip()

    proveedor = valor_de("APP_PAGOS_PROVEEDOR")
    if proveedor:
        ajustes.append("APP_PAGOS_PROVEEDOR=%s" % proveedor)
    for nombre in ("MERCADOPAGO_ACCESS_TOKEN", "MERCADOPAGO_WEBHOOK_SECRET",
                   "PAYPAL_CLIENT_ID", "PAYPAL_CLIENT_SECRET", "PAYPAL_AMBIENTE",
                   "STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_MONEDA",
                   "STRIPE_FACTOR_CONVERSION",
                   "APP_PAGOS_QR_CLIENT_ID", "APP_PAGOS_QR_CLIENT_SECRET",
                   "APP_PAGOS_QR_BASE_URL", "APP_PAGOS_QR_ID_ESTABLECIMIENTO",
                   "APP_PAGOS_QR_NOMBRE_ESTABLECIMIENTO", "APP_PAGOS_QR_VIGENCIA",
                   "APP_PAGOS_QR_WEBHOOK_KEY", "APP_PAGOS_QR_WEBHOOK_VALUE",
                   "APP_PAGOS_TRANSFERENCIA_BANCO", "APP_PAGOS_TRANSFERENCIA_CUENTA",
                   "APP_PAGOS_TRANSFERENCIA_TITULAR", "APP_PAGOS_TRANSFERENCIA_NIT",
                   "APP_PAGOS_TRANSFERENCIA_SUCURSAL", "APP_PAGOS_TRANSFERENCIA_MONEDA",
                   "APP_PAGOS_TRANSFERENCIA_INSTRUCCIONES",
                   "APP_PAGOS_MONEDA", "APP_PAGOS_FACTOR_CONVERSION"):
        valor = valor_de(nombre)
        if valor:
            ajustes.append("%s=%s" % (nombre, valor))
    sandbox = valor_de("APP_PAGOS_SANDBOX")
    if sandbox:
        # Se copia tal cual (incluido "false"): queda explicito en App Service
        # que la pasarela NO esta en modo demostracion.
        ajustes.append("APP_PAGOS_SANDBOX=%s"
                       % ("true" if sandbox.lower() in ("1", "true", "si", "yes") else "false"))
    return ajustes


def informar_pagos(ajustes):
    """Informa (sin mostrar la clave) como quedo la pasarela de pagos."""
    nombres = [a.split("=", 1)[0] for a in ajustes]
    if "MERCADOPAGO_ACCESS_TOKEN" in nombres:
        ok("Pasarela de pagos: Mercado Pago configurado en App Service.")
        if "MERCADOPAGO_WEBHOOK_SECRET" not in nombres:
            aviso("Falta MERCADOPAGO_WEBHOOK_SECRET: el webhook seguira "
                  "funcionando (verifica el pago contra la API de Mercado Pago) "
                  "pero sin validar la firma de la notificacion.")
    elif "PAYPAL_CLIENT_ID" in nombres and "PAYPAL_CLIENT_SECRET" in nombres:
        ok("Pasarela de pagos: PayPal configurado en App Service.")
    elif "STRIPE_SECRET_KEY" in nombres:
        ok("Pasarela de pagos: Stripe configurado en App Service.")
        if "STRIPE_WEBHOOK_SECRET" not in nombres:
            aviso("Falta STRIPE_WEBHOOK_SECRET: el webhook seguira funcionando "
                  "(verifica el pago contra la API de Stripe) pero sin validar "
                  "la firma de la notificacion.")
    elif "APP_PAGOS_QR_CLIENT_ID" in nombres and "APP_PAGOS_QR_CLIENT_SECRET" in nombres:
        ok("Pasarela de pagos: QR Simple (Red Enlace) configurado en App Service.")
        if "APP_PAGOS_QR_ID_ESTABLECIMIENTO" not in nombres:
            aviso("Falta APP_PAGOS_QR_ID_ESTABLECIMIENTO: la API de QR Simple "
                  "exige el id del establecimiento registrado en ATC.")
        if "APP_PAGOS_QR_WEBHOOK_VALUE" not in nombres:
            aviso("Falta APP_PAGOS_QR_WEBHOOK_VALUE: no se podra validar la "
                  "notificacion de pago por QR.")
    elif "APP_PAGOS_SANDBOX" in nombres:
        aviso("Pasarela de pagos en MODO DEMOSTRACION (APP_PAGOS_SANDBOX=true): "
              "los pagos se aprueban sin cobrar. No lo dejes asi en produccion.")
    else:
        aviso("Pasarela de pagos SIN CONFIGURAR: la pantalla de suscripcion avisara "
              "que falta la credencial y no se cobrara nada (no se simula el pago).")
        aviso("Para cobrarla de verdad: define MERCADOPAGO_ACCESS_TOKEN (o las "
              "claves de PayPal, de Stripe o de QR Simple) en Windows y vuelve a desplegar.")


def informar_ia(ajustes):
    """Informa (sin mostrar la clave) como quedo configurada la IA en la nube."""
    nombres = [a.split("=", 1)[0] for a in ajustes]
    valores = dict(a.split("=", 1) for a in ajustes)
    if "GROQ_API_KEY" in nombres:
        ok("IA configurada en App Service: Groq (modelo %s)."
           % valores.get("GROQ_MODEL", "openai/gpt-oss-120b"))
    if "GEMINI_API_KEY" in nombres:
        ok("IA configurada en App Service: Gemini (modelo %s)."
           % valores.get("GEMINI_MODEL", "gemini-3.8-flash"))
    if "GROQ_API_KEY" not in nombres and "GEMINI_API_KEY" not in nombres:
        aviso("La IA quedara en MODO GUIADO (sin clave de LLM): el chat y el "
              "constructor de consultas siguen funcionando, pero las preguntas "
              "en lenguaje natural no tendran respuesta inteligente.")
        aviso("Para activarla: ejecuta 'python configurar_ia.py' (crea ia_config.json) "
              "o define GROQ_API_KEY / GEMINI_API_KEY en Windows, y vuelve a desplegar.")


def claves_ia_cli(args):
    """Claves de IA tecleadas por linea de comandos (si existen)."""
    return {"groq": getattr(args, "groq_clave", None), "gemini": getattr(args, "gemini_clave", None)}


def reaplicar_variables_entorno(cfg, claves_cli=None):
    """
    Vuelve a fijar en App Service las variables que el usuario puede cambiar
    entre despliegues (sobre todo las claves de la IA y las carpetas
    escribibles). No recrea nada.
    """
    if not cfg.get("webapp"):
        return
    rg = cfg.get("resource_group")
    webapp = cfg["webapp"]
    ajustes = ajustes_ia(claves_cli)
    ajustes_pago = ajustes_pagos()
    # Las carpetas del contenedor: el backend usa rutas relativas portables y en
    # Azure conviene apuntarlas a /home/site/wwwroot (el disco del contenedor).
    rutas = ["APP_ARCHIVOS_CARPETA=/home/site/wwwroot/uploads",
             "APP_RESPALDOS_CARPETA=/home/site/wwwroot/respaldos",
             "APP_AUDITORIA_ARCHIVO=/home/site/wwwroot/logs/auditoria_sp3.log"]
    # La URL publica cambia con el despliegue: sin ella el webhook de pagos
    # apuntaria a localhost y la pasarela nunca confirmaria el cobro.
    url_publica = cfg.get("webapp_url")
    if url_publica:
        rutas.append("APP_URL_PUBLICA=%s" % url_publica.rstrip("/"))
    # La clave del Super Admin de la plataforma: si el usuario la define en el
    # entorno, se manda a Azure (si no, el backend usa la clave por defecto).
    clave_super = os.environ.get("APP_SUPERADMIN_PASSWORD")
    if clave_super:
        rutas.append("APP_SUPERADMIN_PASSWORD=%s" % clave_super)
    if not ajustes:
        aviso("No hay claves de IA configuradas (ia_config.json ni variables de "
              "entorno): la IA sigue en modo guiado.")
    info("Actualizando las variables de entorno en App Service (carpetas, IA y pagos)...")
    ejecutar([*az_cmd(), "webapp", "config", "appsettings", "set",
              "-g", rg, "-n", webapp, "--settings", *(rutas + ajustes + ajustes_pago),
              "--only-show-errors", "--output", "none"])
    if ajustes:
        informar_ia(ajustes)
    if ajustes_pago:
        informar_pagos(ajustes_pago)
    ok("Variables de entorno actualizadas. La app las lee al arrancar "
       "(si no, reinicia desde el portal: 'Reiniciar').")


def asegurar_runner_sql():
    """Crea en .tools/sqlrunner un mini programa Node con el driver 'pg' (no requiere psql)."""
    if DRY:
        info("Modo simulado: usaria el runner Node (.tools/sqlrunner) para ejecutar el SQL en Neon.")
        return
    os.makedirs(SQLRUNNER_DIR, exist_ok=True)
    package = os.path.join(SQLRUNNER_DIR, "package.json")
    runner = os.path.join(SQLRUNNER_DIR, "ejecutar_sql.js")
    if not os.path.isfile(package):
        with open(package, "w", encoding="utf-8") as f:
            f.write(SQLRUNNER_PACKAGE)
    if not os.path.isfile(runner):
        with open(runner, "w", encoding="utf-8") as f:
            f.write(SQLRUNNER_JS)
    if not os.path.isdir(os.path.join(SQLRUNNER_DIR, "node_modules", "pg")):
        npm = shutil.which("npm")
        if not npm:
            fatal("Se necesita Node.js/npm para cargar el SQL en Neon: https://nodejs.org")
        info("Instalando el driver Node 'pg' en .tools/sqlrunner (una sola vez)...")
        rc = ejecutar(comando_windows(npm) + ["install", "--no-audit", "--no-fund"], cwd=SQLRUNNER_DIR)
        if rc != 0:
            fatal("No se pudo instalar el driver 'pg'. Revisa tu conexion a internet.")
        ok("Driver 'pg' listo.")


def ejecutar_sql_neon(cfg, archivo, obligatorio=False):
    ruta = os.path.join(DATABASE, archivo)
    if not os.path.isfile(ruta):
        if obligatorio:
            fatal("Falta el script %s" % archivo)
        aviso("No existe %s, lo salto." % archivo)
        return True
    info("Ejecutando %s en Neon..." % archivo)
    if DRY:
        print(C.AMARILLO + "  $ node .tools/sqlrunner/ejecutar_sql.js " + archivo + C.AZUL + "   (simulado)" + C.RESET)
        return True
    env = os.environ.copy()
    env["DATABASE_URL"] = cfg["neon_url"]
    node = shutil.which("node")
    rc = ejecutar(comando_windows(node) + [os.path.join(SQLRUNNER_DIR, "ejecutar_sql.js"), ruta], env=env)
    if rc == 0:
        ok("%s aplicado en Neon." % archivo)
        return True
    if obligatorio:
        fatal("No se pudo ejecutar %s en Neon." % archivo)
    aviso("No se pudo ejecutar %s; el backend tambien crea tablas base al arrancar." % archivo)
    return False


def consultar_neon(cfg, sql):
    """Ejecuta una consulta y devuelve el valor de la primera columna (texto)."""
    if DRY:
        return ""
    env = os.environ.copy()
    env["DATABASE_URL"] = cfg["neon_url"]
    node = shutil.which("node")
    if not node:
        return ""
    try:
        # Solo se lee stdout: el driver 'pg' escribe avisos de SSL en stderr.
        proceso = subprocess.run([node, os.path.join(SQLRUNNER_DIR, "ejecutar_sql.js"),
                                  "--consulta", sql],
                                 env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 timeout=180)
    except Exception:
        return ""
    if proceso.returncode != 0:
        return ""
    return proceso.stdout.decode("utf-8", "replace").strip()


# Consulta de "listo": el backend ya aplico la migracion V3, creo la empresa
# demo y las tablas, y el inicializador sembro areas, roles y categorias.
CONSULTA_ESQUEMA_LISTO = (
    "SELECT (to_regclass('public.empresa') IS NOT NULL "
    "AND to_regclass('public.area') IS NOT NULL "
    "AND to_regclass('public.ejecucion_presupuestaria') IS NOT NULL "
    "AND (SELECT count(*) FROM empresa WHERE id = 1) > 0 "
    "AND (SELECT count(*) FROM area WHERE empresa_id = 1) > 0 "
    "AND (SELECT count(*) FROM rol WHERE empresa_id = 1) > 0 "
    "AND (SELECT count(*) FROM categoria) > 0)")

# Tablas que DEBEN tener datos de fabrica (si alguna queda vacia, el usuario
# veria una pantalla en blanco y pensaria que la app esta rota).
TABLAS_DATOS_FABRICA = [
    "empresa", "cuenta", "plan", "suscripcion", "pago", "configuracion_empresa",
    "rol", "usuario", "categoria", "area", "ubicacion", "activo",
    "asignacion", "historial_estado_activo", "mantenimiento",
    "presupuesto", "partida_presupuestaria", "ejecucion_presupuestaria",
    "verificacion_inventario", "consulta_guardada", "respaldo",
    "programacion_respaldo", "bitacora_auditoria",
]


def esperar_esquema_listo(cfg, segundos=240):
    """
    Espera a que el backend termine su inicializacion REAL (migracion V3, areas,
    roles y categorias), no solo a que responda HTTP.

    El puerto HTTP responde antes de que corran los CommandLineRunner: si los
    seeds se ejecutan en ese instante, el seed del Sprint 2 inserta cero filas
    (las areas todavia no existen) y el del Sprint 3 falla con
    "null value in column partida_id", dejando la aplicacion sin datos.
    """
    if DRY:
        info("Modo simulado: esperaria a que la base este lista antes de sembrar.")
        return True
    info("Esperando a que el backend termine la migracion V3 y la siembra inicial...")
    paso = 10
    waited = 0
    while waited < segundos:
        valor = consultar_neon(cfg, CONSULTA_ESQUEMA_LISTO)
        # PostgreSQL devuelve el booleano como 't'/'f'; el driver de Node lo
        # imprime como 'true'/'false'. Se aceptan ambas formas.
        if valor.strip().lower() in ("t", "true", "1", "yes"):
            ok("Esquema listo: empresa demo, areas, roles y categorias ya existen.")
            return True
        esperar(paso, "La base todavia no esta lista (areas/roles sin sembrar)...")
        waited += paso
    aviso("La base no marco el esquema como listo en %d s. Se intentara sembrar de todos modos."
          % segundos)
    return False


def verificar_datos_fabrica(cfg):
    """Cuenta las filas de cada tabla de negocio y avisa de las que quedaron vacias."""
    if DRY:
        return []
    if cfg.get("tipo_bd") != TIPO_BD_NEON:
        info("Verificacion automatica de filas: disponible solo con Neon "
             "(en Azure PostgreSQL se revisa a mano).")
        return []
    consulta = ("SELECT string_agg(nombre || '=' || total, ', ') FROM ("
                + " UNION ALL ".join("SELECT '%s' AS nombre, count(*)::text AS total FROM %s" % (t, t)
                                    for t in TABLAS_DATOS_FABRICA)
                + ") t")
    texto = consultar_neon(cfg, consulta)
    if not texto:
        aviso("No se pudo verificar los datos de fabrica (la consulta fallo).")
        return []
    vacias = []
    for parte in texto.split(","):
        if "=" not in parte:
            continue
        nombre, total = parte.split("=", 1)
        nombre = nombre.strip()
        total = total.strip()
        try:
            n = int(total)
        except ValueError:
            continue
        if n == 0:
            vacias.append(nombre)
    info("Datos de fabrica por tabla:")
    for parte in texto.split(","):
        if "=" in parte:
            print("        %s" % parte.strip())
    if vacias:
        aviso("Tablas sin datos de fabrica: %s." % ", ".join(vacias))
        aviso("Espera un par de minutos y ejecuta: python desplegar_azure.py --solo-app")
    else:
        ok("Las %d tablas de negocio tienen datos ficticios de fabrica." % len(TABLAS_DATOS_FABRICA))
    # Ronda 10:_revision por empresa (ninguna empresa con pantallas vacias)
    consulta_empresas = (
        "SELECT e.id || '|' || e.nombre || '|' "
        "|| (SELECT count(*) FROM activo a WHERE a.empresa_id = e.id) || '|' "
        "|| (SELECT count(*) FROM presupuesto p WHERE p.empresa_id = e.id) || '|' "
        "|| (SELECT count(*) FROM mantenimiento m WHERE m.empresa_id = e.id) || '|' "
        "|| (SELECT count(*) FROM consulta_guardada c WHERE c.empresa_id = e.id) || '|' "
        "|| (SELECT count(*) FROM verificacion_inventario v WHERE v.empresa_id = e.id) "
        "FROM empresa e WHERE e.id > 0 ORDER BY e.id")
    texto_empresas = consultar_neon(cfg, consulta_empresas)
    if texto_empresas:
        info("Datos por empresa (activos|presupuestos|mantenimientos|consultas|inventario):")
        incompletas = []
        for linea in texto_empresas.splitlines():
            linea = linea.strip()
            if "|" not in linea:
                continue
            partes = linea.split("|")
            if len(partes) < 6:
                continue
            print("        %s -> %s|%s|%s|%s|%s" % (partes[0], partes[1], partes[2],
                                                    partes[3], partes[4], partes[5]))
            try:
                vacias_empresa = [int(x) for x in partes[2:6]]
            except ValueError:
                continue
            if sum(vacias_empresa) == 0:
                incompletas.append("%s (%s)" % (partes[0], partes[1]))
        if incompletas:
            aviso("Empresas sin datos de ejemplo: %s." % ", ".join(incompletas))
        else:
            ok("Todas las empresas tienen datos de ejemplo en todas sus funciones.")
    return vacias


def obtener_cadena_neon(args, cfg):
    """Pide/recupera la cadena de conexion de Neon y la valida."""
    url = args.neon_cadena or os.environ.get("NEON_DATABASE_URL") or cfg.get("neon_url")
    if not url:
        if DRY:
            url = "postgresql://usuario:clave@ep-ejemplo-12345.us-east-2.aws.neon.tech/neondb?sslmode=require"
        else:
            print("\n  Para crear la base gratis (2 minutos, sin tarjeta):")
            print("    1) Entra a https://console.neon.tech y registrate (GitHub o Google).")
            print("    2) Crea un proyecto (region cualquiera; si hay opciones, la mas cercana).")
            print("    3) Copia la cadena de conexion que empieza por 'postgresql://...'")
            print("       (en 'Connection string', elige la version directa, sin '-pooler', para Spring Boot).")
            try:
                url = input("  Pega aqui la cadena de conexion de Neon: ").strip()
            except EOFError:
                fatal("Se necesita la cadena de conexion de Neon (usa --neon-cadena o la variable NEON_DATABASE_URL).")
    datos = parsear_url_postgres(url)
    # Los caracteres especiales de cmd (& | < > ^) en usuario/clave partirian la
    # linea de comandos al configurar App Service. Las claves de Neon por defecto
    # son alfanumericas con guion bajo; si aparecen esos simbolos, se avisa claro.
    prohibidos = set("&|<>^\"")
    if any(c in prohibidos for c in (datos["user"] + datos["password"])):
        fatal("El usuario o la contrasena de Neon contienen caracteres que rompen la "
              "consola de Windows (&, |, <, >, ^). Regenera la contrasena en la consola "
              "de Neon (Neon nunca usa esos simbolos en sus claves generadas).")
    cfg["neon_url"] = url.strip()
    cfg["neon_host"] = datos["host"]
    cfg["neon_db"] = datos["database"]
    guardar_config(cfg)
    ok("Cadena de Neon registrada (host: %s, base: %s)." % (datos["host"], datos["database"]))
    return url


# --------------------------------------------------------------------------- Azure: base de datos

def asegurar_extension_sql():
    # En versiones nuevas el comando ya viene incluido; en otras requiere la extension rdbms-connect.
    info("Verificando la extension 'rdbms-connect' para ejecutar SQL...")
    ejecutar([*az_cmd(), "extension", "add", "--name", "rdbms-connect", "--only-show-errors",
              "--output", "none"], mostrar=False)


def ejecutar_script_sql(cfg, archivo, obligatorio=False):
    ruta = os.path.join(DATABASE, archivo)
    if not os.path.isfile(ruta):
        if obligatorio:
            fatal("Falta el script %s" % archivo)
        aviso("No existe %s, lo salto." % archivo)
        return True
    info("Ejecutando %s en la base de datos..." % archivo)
    cmd = [*az_cmd(), "postgres", "flexible-server", "execute",
           "--name", cfg["pg_server"],
           "--admin-user", PG_USUARIO,
           "--admin-password", cfg["pg_password"],
           "--database-name", NOMBRE_BD,
           "--file-path", ruta,
           "--only-show-errors"]
    rc = ejecutar(cmd)
    if rc == 0:
        ok("%s aplicado." % archivo)
        return True

    # plan B: psql local, si esta instalado
    psql = shutil.which("psql")
    if psql:
        aviso("'az ... execute' fallo; reintento con psql local.")
        env = os.environ.copy()
        env["PGPASSWORD"] = cfg["pg_password"]
        rc = ejecutar(comando_windows(psql) + [
            "host=%s port=5432 dbname=%s user=%s sslmode=require"
            % (cfg["pg_host"], NOMBRE_BD, PG_USUARIO),
            "-f", ruta], env=env)
        if rc == 0:
            ok("%s aplicado con psql." % archivo)
            return True
    if obligatorio:
        fatal("No se pudo ejecutar %s. Puedes correrlo a mano con psql o desde Azure Data Studio." % archivo)
    aviso("No se pudo ejecutar %s, pero el backend tambien inicializa lo esencial al arrancar." % archivo)
    return False


def cargar_datos_iniciales(cfg, con_demo):
    titulo("PASO 6b/7 - Esquema y datos iniciales en la base de datos")
    # Solo el esquema. Las semillas se aplican en el PASO 7b, cuando el backend
    # ya arranco y creo las columnas empresa_id y las tablas de los Sprints 2 y 3
    # (si se siembran antes, el script falla y la base queda vacia).
    if cfg.get("tipo_bd") == TIPO_BD_NEON:
        asegurar_runner_sql()
        ejecutar_sql_neon(cfg, "schema.sql", obligatorio=True)
        return
    asegurar_extension_sql()
    ejecutar_script_sql(cfg, "schema.sql", obligatorio=True)


def _ejecutar_seed_con_reintento(cfg, archivo, ejecutor):
    """El puerto HTTP responde antes de que el backend termine la migracion V3;
    si el seed llega demasiado temprano falla por tablas inexistentes. Los
    scripts son idempotentes, asi que se reintenta con pausas crecientes."""
    pausas = (10, 20, 30, 45)
    for intento, pausa in enumerate(pausas, start=1):
        if ejecutor(cfg, archivo):
            return True
        if intento < len(pausas):
            esperar(pausa, "Esquema V3 aun no listo para %s, reintento %d/%d"
                           % (archivo, intento, len(pausas) - 1))
    aviso("No se pudo confirmar la carga de %s tras varios reintentos." % archivo)
    return False


def cargar_datos_fabrica(cfg, url_base=None, con_demo=True):
    """
    Carga los datos ficticios de fabrica UNA VEZ QUE LA BASE ESTA LISTA.

    Orden correcto (el que fallaba en la nube):
      1. esperar a que el backend termine la migracion V3 y siembre areas/roles;
      2. sembrar el Sprint 2 (presupuestos y partidas);
      3. sembrar el Sprint 3 (todas las tablas de negocio);
      4. verificar cuanto hay en cada tabla y avisar de las vacias.
    """
    titulo("PASO 7b/7 - Datos de fabrica y verificacion")
    if cfg.get("tipo_bd") == TIPO_BD_NEON:
        asegurar_runner_sql()
        esperar_esquema_listo(cfg)
        # Orden importante: los usuarios y los activos de ejemplo ANTES que los
        # seeds de los Sprints 2 y 3, porque se apoyan en ellos (asignaciones,
        # mantenimientos, presupuestos). Ademas el seed de los usuarios necesita
        # la columna empresa_id, que agrega la migracion V3.
        _ejecutar_seed_con_reintento(cfg, "fix_usuarios_prueba.sql", ejecutar_sql_neon)
        if con_demo:
            _ejecutar_seed_con_reintento(cfg, "seed_datos_ficticios.sql", ejecutar_sql_neon)
        else:
            info("--sin-datos-demo: no cargo activos ficticios.")
        # El seed del Sprint 2 crea areas, presupuestos y partidas.
        _ejecutar_seed_con_reintento(cfg, "seed_sprint2_datos.sql", ejecutar_sql_neon)
        # Datos de fabrica del Sprint 3: rellena todas las tablas de negocio.
        _ejecutar_seed_con_reintento(cfg, "seed_sprint3_datos.sql", ejecutar_sql_neon)
        # Multiempresa: cuentas globales y la segunda empresa de demostracion.
        _ejecutar_seed_con_reintento(cfg, "seed_multiempresa_datos.sql", ejecutar_sql_neon)
    else:
        _ejecutar_seed_con_reintento(cfg, "fix_usuarios_prueba.sql", ejecutar_script_sql)
        if con_demo:
            _ejecutar_seed_con_reintento(cfg, "seed_datos_ficticios.sql", ejecutar_script_sql)
        else:
            info("--sin-datos-demo: no cargo activos ficticios.")
        _ejecutar_seed_con_reintento(cfg, "seed_sprint2_datos.sql", ejecutar_script_sql)
        _ejecutar_seed_con_reintento(cfg, "seed_sprint3_datos.sql", ejecutar_script_sql)
        _ejecutar_seed_con_reintento(cfg, "seed_multiempresa_datos.sql", ejecutar_script_sql)
    if url_base:
        recalcular_depreciacion(url_base)
        # Ronda 10: ninguna empresa se queda con pantallas vacias.
        completar_datos_ejemplo(url_base)
        # Ronda 11: los metodos de pago (Stripe, QR, transferencia) responden.
        verificar_pagos_r11(url_base)
    verificar_datos_fabrica(cfg)


def verificar_pagos_r11(url_base):
    """Ronda 11: comprueba que los endpoints de pago funcionan en el sitio ya
    desplegado (metodos de pago publicos y listado de transferencias del
    administrador de la plataforma). Si algo falla, lo dice con el error real:
    el despliegue nunca debe terminar con un "listo" que esconda un fallo."""
    if DRY:
        info("Modo simulado: comprobaria los endpoints de pago.")
        return True
    if not url_base:
        return True
    bien = True
    codigo, cuerpo = peticion_http(url_base + "/api/public/metodos-pago")
    if codigo != 200:
        aviso("El endpoint de metodos de pago devolvio HTTP %d (%s)."
              % (codigo, (cuerpo or "")[:200]))
        bien = False
    else:
        try:
            metodos = json.loads(cuerpo)
            nombres = [str(m.get("codigo", "")) for m in metodos] if isinstance(metodos, list) else []
        except Exception:
            nombres = []
        if "STRIPE" in nombres and "TRANSFERENCIA" in nombres:
            ok("Metodos de pago disponibles: %s." % ", ".join(n for n in nombres if n))
        else:
            aviso("El backend no ofrecio los metodos de pago esperados (llego: %s)."
                  % (", ".join(nombres) or "nada"))
            bien = False
    # Listado de transferencias (administrador de la plataforma).
    correo = os.environ.get("APP_SUPERADMIN_CORREO", "superadmin@plataforma.local")
    clave = os.environ.get("APP_SUPERADMIN_PASSWORD", "Cambiar123!")
    codigo, cuerpo = peticion_http(url_base + "/api/auth/login",
                                    datos={"correo": correo, "password": clave})
    token = ""
    try:
        token = json.loads(cuerpo).get("token", "")
    except Exception:
        token = ""
    if not token:
        aviso("No pude iniciar sesion como Super Admin para verificar las transferencias "
              "(revisa APP_SUPERADMIN_PASSWORD).")
        return bien
    req = urllib.request.Request(url_base + "/api/plataforma/pagos/transferencias",
                                 headers={"Authorization": "Bearer " + token}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            if resp.getcode() == 200:
                ok("El listado de transferencias bancarias responde correctamente.")
            else:
                aviso("El listado de transferencias devolvio HTTP %d." % resp.getcode())
                bien = False
    except Exception as e:
        aviso("No se pudo consultar el listado de transferencias (%s)." % e)
        bien = False
    return bien


def completar_datos_ejemplo(url_base):
    """Ronda 10: pide al backend que complete los datos de ejemplo de TODAS
    las empresas (categorias, areas, ubicaciones, activos, asignaciones,
    mantenimiento, presupuesto con partidas y ejecuciones, consultas
    guardadas, verificaciones de inventario, historial de estados,
    configuracion y programacion de respaldo).

    Solo crea lo que falta: no pisa ningun dato real. Si el backend no
    responde, se avisa (los datos de ejemplo de cada empresa nueva ya se
    siembran al registrarse)."""
    if DRY:
        info("Modo simulado: completaria los datos de ejemplo de todas las empresas.")
        return True
    if not url_base:
        return True
    correo = os.environ.get("APP_SUPERADMIN_CORREO", "superadmin@plataforma.local")
    clave = os.environ.get("APP_SUPERADMIN_PASSWORD", "Cambiar123!")
    codigo, cuerpo = peticion_http(url_base + "/api/auth/login",
                                   datos={"correo": correo, "password": clave})
    token = ""
    try:
        token = json.loads(cuerpo).get("token", "")
    except Exception:
        token = ""
    if not token:
        aviso("No pude iniciar sesion como Super Admin para completar los datos de ejemplo "
              "(las empresas nuevas ya los siembran al registrarse).")
        return False
    req = urllib.request.Request(url_base + "/api/plataforma/datos-ejemplo", data=b"",
                                 headers={"Authorization": "Bearer " + token}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            if resp.getcode() == 200:
                info("Datos de ejemplo completados en todas las empresas: %s"
                     % resp.read().decode("utf-8", "replace")[:300])
                return True
            aviso("La siembra de datos de ejemplo devolvio HTTP %d." % resp.getcode())
            return False
    except Exception as e:
        aviso("No se pudieron completar los datos de ejemplo (%s)." % e)
        return False


def recalcular_depreciacion(url_base):
    """Pide el calculo de la depreciacion para que la pantalla no salga vacia."""
    if DRY:
        info("Modo simulado: pediria el calculo de depreciacion.")
        return
    codigo, cuerpo = peticion_http(url_base + "/api/auth/login",
                                   datos={"correo": "admin@uagrm.edu.bo", "password": "admin123"})
    token = ""
    try:
        token = json.loads(cuerpo).get("token", "")
    except Exception:
        token = ""
    if not token:
        aviso("No pude iniciar sesion para recalcular la depreciacion "
              "(se hara sola el dia 1 de cada mes).")
        return
    # POST /api/depreciacion/calcular (periodo opcional; por defecto, el actual).
    try:
        req = urllib.request.Request(url_base + "/api/depreciacion/calcular", data=b"",
                                     headers={"Authorization": "Bearer " + token}, method="POST")
        with urllib.request.urlopen(req, timeout=180) as resp:
            if resp.getcode() == 200:
                ok("Depreciacion recalculada: la pantalla de depreciacion ya tiene datos.")
            else:
                aviso("El calculo de depreciacion devolvio HTTP %d." % resp.getcode())
    except Exception as e:
        aviso("No se pudo recalcular la depreciacion (%s); "
              "se calculara sola el dia 1 de cada mes." % e)


# --------------------------------------------------------------------------- Azure: despliegue del JAR

def reintentar_despliegue(nombre, construir_comando, intentos, pausas):
    """
    Ejecuta una subida a Azure reintentando los cortes de red transitorios
    (ConnectionReset 10054, 'Connection aborted', timeouts). Las subidas de un
    JAR de ~57 MB por enlaces largos (Bolivia -> Europa) se cortan a veces sin
    que la configuracion tenga ningun problema; un segundo intento casi siempre basta.
    Devuelve el ultimo codigo de salida (0 = exito).
    """
    rc = 1
    for intento in range(1, intentos + 1):
        if intento > 1:
            esperar(pausas[intento - 2],
                    "Reintento %d/%d del %s" % (intento, intentos, nombre))
        rc = ejecutar(construir_comando())
        if rc == 0:
            if intento > 1:
                ok("%s exitoso en el intento %d." % (nombre, intento))
            return 0
        if intento < intentos:
            aviso("%s fallo (intento %d/%d). Los cortes de conexion al subir el JAR "
                  "son transitorios; reintento sin tocar la infraestructura..."
                  % (nombre, intento, intentos))
    return rc


def comprobar_conectividad_scm(webapp):
    """
    Verifica que el endpoint de despliegue (SCM/Kudu) es alcanzable antes de
    empezar a subir 57 MB. Un 401/403 tambien vale: demuestra que la conexion TLS
    llega; solo el codigo 0 (error de red sin respuesta HTTP) indica problema.
    """
    if DRY:
        return True
    url = "https://%s.scm.azurewebsites.net" % webapp
    for intento in (1, 2, 3):
        codigo, _ = peticion_http(url)
        if codigo != 0:
            ok("Conectividad con el servicio de despliegue de Azure (SCM) verificada (HTTP %s)." % codigo)
            return True
        if intento < 3:
            esperar(10, "El endpoint SCM no responde (intento %d/3)" % intento)
    aviso("No pude alcanzar %s. Si tu red usa proxy, VPN o un antivirus con "
          "inspeccion HTTPS, alguno puede interrumpir la subida del JAR; si el "
          "despliegue falla, prueba con otra red (p. ej. el punto de acceso del celular)."
          % url)
    return False


def preparar_jar_para_subida(jar):
    """
    OneDrive (Files On-Demand / sincronizacion) puede bloquear o ralentizar
    lecturas largas de archivos grandes. Si el JAR vive dentro de una carpeta
    OneDrive, se copia a una ruta local temporal y se sube desde alli.
    Devuelve (ruta_para_subir, carpeta_temporal_o_None).
    """
    if "onedrive" not in jar.lower():
        return jar, None
    import tempfile
    tmp = tempfile.mkdtemp(prefix="activosfijos-deploy-")
    destino = os.path.join(tmp, "app.jar")
    info("El JAR esta dentro de OneDrive; lo copio a una carpeta local temporal antes de subirlo...")
    shutil.copy2(jar, destino)
    return destino, tmp


def desplegar_via_storage(cfg, jar):
    """
    Plan C: subir el JAR a Azure Storage en bloques (cada bloque es una peticion
    corta con reintentos internos) y pedir a App Service que LO DESCARGUE desde
    Azure mediante una URL SAS. Asi el PC nunca mantiene la conexion larga que
    los antivirus/VPN/proxies cortan con el error ConnectionReset 10054.

    Costo: una cuenta Standard_LRS con 57 MB durante unos minutos y borrada al
    terminar: fraccion de centavo de dolar (se elimina automaticamente).
    Devuelve 0 si el despliegue funciono; otro valor si fallo.
    """
    rg, webapp = cfg["resource_group"], cfg["webapp"]
    sufijo = webapp.rsplit("-", 1)[-1] if "-" in webapp else sufijo_aleatorio()
    cuenta = ("stactivos" + sufijo)[:24]
    region = cfg.get("region_efectiva") or cfg.get("region") or "francecentral"
    contenedor = "deployes"
    info("Plan C (despliegue indirecto): creo una cuenta de Storage temporal en %s..." % region)
    rc = ejecutar([*az_cmd(), "storage", "account", "create",
                   "-g", rg, "-n", cuenta, "-l", region,
                   "--sku", "Standard_LRS", "--kind", "StorageV2",
                   "--allow-blob-public-access", "false",
                   "--min-tls-version", "TLS1_2",
                   "--only-show-errors"])
    if rc != 0:
        aviso("No se pudo crear la cuenta de Storage; se omite el plan C.")
        return rc
    try:
        rc_cs, salida_cs = capturar([*az_cmd(), "storage", "account", "show-connection-string",
                                     "-g", rg, "-n", cuenta, "-o", "tsv", "--only-show-errors"])
        cadena = salida_cs.strip().strip('"').strip()
        if rc_cs != 0 or not cadena:
            aviso("No pude obtener la cadena de conexion de la cuenta de Storage.")
            return 1
        # el contenedor puede tardar unos segundos en poder usarse tras crear la cuenta
        for intento in (1, 2, 3):
            rc_cont = ejecutar([*az_cmd(), "storage", "container", "create",
                                "--connection-string", cadena, "-n", contenedor,
                                "--only-show-errors", "--output", "none"])
            if rc_cont == 0:
                break
            if intento < 3:
                esperar(15, "Storage aun se esta aprovisionando (intento %d/3)" % intento)
        else:
            aviso("No se pudo crear el contenedor de blobs en Storage.")
            return 1
        # subida en bloques: si un bloque falla, el SDK reintenta solo ese bloque
        rc_up = reintentar_despliegue(
            "subida por bloques a Storage",
            lambda: [*az_cmd(), "storage", "blob", "upload",
                     "--connection-string", cadena,
                     "-c", contenedor, "-n", "app.jar",
                     "-f", jar, "--overwrite", "--only-show-errors"],
            2, (20,))
        if rc_up != 0:
            aviso("La subida por bloques a Storage tampoco funciono.")
            return rc_up
        # SAS de solo lectura valida 2 horas; --full-uri devuelve la URL completa
        expira = (datetime.datetime.now(datetime.timezone.utc)
                  + datetime.timedelta(hours=2)).strftime("%Y-%m-%dT%H:%MZ")
        rc_sas, salida_sas = capturar([*az_cmd(), "storage", "blob", "generate-sas",
                                       "--connection-string", cadena,
                                       "-c", contenedor, "-n", "app.jar",
                                       "--permissions", "r", "--expiry", expira,
                                       "--full-uri", "-o", "tsv", "--only-show-errors"])
        url_sas = salida_sas.strip().splitlines()[-1].strip().strip('"') if salida_sas else ""
        if rc_sas != 0 or not url_sas.startswith("https://"):
            aviso("No pude generar la URL SAS del blob.")
            return 1
        # App Service descarga el JAR desde Azure (no desde tu PC)
        rc = ejecutar([*az_cmd(), "webapp", "deploy",
                       "--resource-group", rg, "--name", webapp,
                       "--type", "jar", "--src-url", url_sas,
                       "--clean", "true", "--timeout", "1800",
                       "--only-show-errors"])
        return rc
    finally:
        info("Borrando la cuenta de Storage temporal (la aplicacion ya no la necesita)...")
        ejecutar([*az_cmd(), "storage", "account", "delete",
                  "-g", rg, "-n", cuenta, "-y",
                  "--only-show-errors", "--output", "none"])


def desplegar_jar(cfg, jar, via_storage=False, permitir_storage=True):
    titulo("PASO 7/7 - Desplegando el JAR en App Service")
    rg, webapp = cfg["resource_group"], cfg["webapp"]
    if not via_storage:
        comprobar_conectividad_scm(webapp)
    jar, tmp_staging = preparar_jar_para_subida(jar)
    try:
        tamano_mb = os.path.getsize(jar) / 1048576.0
        info("Paquete a subir: %.1f MB. En una conexion lenta puede tardar varios minutos; "
             "no cierres la ventana." % tamano_mb)
        if via_storage:
            if DRY:
                info("Modo simulado: haria el despliegue indirecto via Azure Storage.")
                return
            if desplegar_via_storage(cfg, jar) == 0:
                ok("JAR desplegado en App Service (via Storage).")
                return
            fatal("El despliegue via Storage fallo. Revisa los mensajes anteriores.")

        # El flag correcto de 'az webapp deploy' es --src-path (--path nunca existio
        # para este subcomando y la CLI 2.9x lo rechaza). type=jar lo coloca en
        # /home/site/wwwroot/app.jar y App Service Java SE lo arranca automaticamente.
        # --timeout 1800 da margen de 30 min para la operacion completa en F1.
        comando_jar = lambda: [*az_cmd(), "webapp", "deploy",
                               "--resource-group", rg,
                               "--name", webapp,
                               "--type", "jar",
                               "--src-path", jar,
                               "--clean", "true",
                               "--timeout", "1800",
                               "--only-show-errors"]
        rc = reintentar_despliegue("despliegue JAR (OneDeploy)", comando_jar, 3, (20, 60))
        if rc != 0:
            aviso("El despliegue directo no funciono; preparo el plan B (zip deploy)...")
            # alternativa: comprimir el jar como app.jar y hacer zip deploy.
            # El zip se construye UNA sola vez y se reutiliza en todos los reintentos.
            import tempfile
            with tempfile.TemporaryDirectory() as tmp:
                app_jar = os.path.join(tmp, "app.jar")
                shutil.copy2(jar, app_jar)
                zip_ruta = os.path.join(tmp, "app.zip")
                with zipfile.ZipFile(zip_ruta, "w", zipfile.ZIP_DEFLATED) as z:
                    z.write(app_jar, "app.jar")
                comando_zip = lambda: [*az_cmd(), "webapp", "deployment", "source", "config-zip",
                                       "--resource-group", rg,
                                       "--name", webapp,
                                       "--src", zip_ruta,
                                       "--timeout", "1800",
                                       "--only-show-errors"]
                rc = reintentar_despliegue("zip deploy", comando_zip, 2, (30,))
                if rc == 0:
                    # el zip deploy de Java SE necesita el comando de arranque explicito
                    rc_start = ejecutar([*az_cmd(), "webapp", "config", "set",
                                         "--resource-group", rg,
                                         "--name", webapp,
                                         "--startup-file", "java -jar /home/site/wwwroot/app.jar",
                                         "--only-show-errors", "--output", "none"])
                    if rc_start != 0:
                        aviso("No se pudo guardar el comando de arranque; reintento una vez...")
                        ejecutar([*az_cmd(), "webapp", "config", "set",
                                  "--resource-group", rg,
                                  "--name", webapp,
                                  "--startup-file", "java -jar /home/site/wwwroot/app.jar",
                                  "--only-show-errors", "--output", "none"])
            if rc != 0 and permitir_storage and not DRY:
                aviso("Los dos metodos de subida directa fallaron; paso al plan C: la subida\n"
                      "  se hara en bloques pequenos a Azure Storage y App Service la descargara\n"
                      "  desde Azure. Cuesta una fraccion de centavo y la cuenta se borra sola.")
                rc = desplegar_via_storage(cfg, jar)
            if rc != 0:
                fatal("No se pudo subir el JAR a Azure tras varios intentos. El problema es\n"
                      "  de RED, no de configuracion: la infraestructura, las variables y la base\n"
                      "  de datos Neon ya estan correctas. La aplicacion que estuviera publicada\n"
                      "  antes sigue funcionando (una subida fallida no reemplaza la version previa).\n"
                      "  Causa tipica del error 'ConnectionReset 10054 / Connection aborted': el\n"
                      "  antivirus con inspeccion HTTPS, una VPN, un proxy o un WiFi inestable\n"
                      "  cortan la conexion de larga duracion que sube el archivo de ~57 MB.\n"
                      "  Que hacer, en orden:\n"
                      "    1) Vuelve a ejecutar Solo_actualizar_app.bat: reintenta solo la subida,\n"
                      "       es idempotente. Si tu red corta siempre las subidas largas, usa\n"
                      "       'python desplegar_azure.py --solo-app --via-storage' para forzar el plan C.\n"
                      "    2) Cambia de red (punto de acceso del celular) o desactiva momentaneamente\n"
                      "       el escaneo HTTPS del antivirus / la VPN, y reintenta.\n"
                      "    3) Como ultimo recurso, ejecuta a mano en esta misma ventana CMD el comando\n"
                      "       'az webapp deploy' que aparece mas arriba (con --src-path y --timeout).\n"
                      "  Cuando la subida termine, el script espera el arranque y prueba el login solo.")
        ok("JAR desplegado en App Service.")
    finally:
        if tmp_staging:
            shutil.rmtree(tmp_staging, ignore_errors=True)


def peticion_http(url, datos=None):
    """Devuelve (codigo_http, cuerpo). Errores de red devuelven (0, mensaje)."""
    cabeceras = {"Content-Type": "application/json"}
    data = None
    if datos is not None:
        data = json.dumps(datos).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=cabeceras,
                                 method="POST" if datos is not None else "GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.getcode(), resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except urllib.error.URLError as e:
        return 0, str(e)


def esperar_arranque(url_base, reintentos=30, espera=20):
    if DRY:
        info("Modo simulado: esperaria el arranque de %s y luego ejecutaria la semilla Sprint 2." % url_base)
        return True
    info("Esperando que la aplicacion arranque en App Service (puede tardar 2-5 minutos en F1)...")
    url_login = url_base + "/api/auth/login"
    for i in range(1, reintentos + 1):
        codigo, _ = peticion_http(url_login, datos={})
        # 400/401/403/405 significan que Spring ya responde (400: falta correo/password)
        if codigo in (400, 401, 403, 405):
            ok("La aplicacion ya responde (HTTP %d)." % codigo)
            return True
        if i == reintentos:
            aviso("La aplicacion aun no responde. Revisa los logs con: python desplegar_azure.py --logs")
            return False
        esperar(espera, "Intento %d/%d (HTTP %s)" % (i + 1, reintentos, codigo or "sin respuesta"))
    return False


def prueba_humo(url_base):
    if DRY:
        info("Modo simulado: haria POST a /api/auth/login con admin@uagrm.edu.bo para validar el servicio.")
        return True
    info("Probando el inicio de sesion con el usuario administrador de prueba...")
    codigo, cuerpo = peticion_http(url_base + "/api/auth/login",
                                   datos={"correo": "admin@uagrm.edu.bo", "password": "admin123"})
    if codigo == 200:
        ok("Inicio de sesion exitoso: el backend y la base de datos funcionan.")
        return True
    aviso("La prueba de login devolvio HTTP %s. Si la base aun se esta inicializando, "
          "espera un par de minutos y reintenta entrar desde el navegador." % codigo)
    return False


# --------------------------------------------------------------------------- flujos del programa

def _buscar_webapp(nombre, suscripcion=None):
    """
    Busca una aplicacion web por nombre. Devuelve (encontrado, datos, salida).
    Primero la pide directo (show) y, si no aparece, la busca en la lista de
    webapps de la suscripcion (a veces 'show' no la encuentra).
    """
    extra = ["--subscription", suscripcion] if suscripcion else []
    codigo, salida = capturar([*az_cmd(), "webapp", "show", "-n", nombre,
                                "--query", "{rg:resourceGroup,host:defaultHostName,"
                                "plan:serverFarmId}", "--only-show-errors"] + extra)
    datos = json_tolerante(salida)
    if codigo == 0 and isinstance(datos, dict) and datos.get("rg"):
        return True, datos, salida
    codigo, salida = capturar([*az_cmd(), "webapp", "list", "--output", "json",
                                "--only-show-errors"] + extra)
    lista = json_tolerante(salida)
    if isinstance(lista, list):
        for app in lista:
            if (app.get("name") or "").lower() == nombre.lower():
                plan = (app.get("serverFarmId") or "").rstrip("/").split("/")[-1]
                return True, {"rg": app.get("resourceGroup"),
                              "host": app.get("defaultHostName"),
                              "plan": plan}, salida
    return False, None, salida


def _listar_webapps(suscripcion=None):
    """Nombres de las webapps de la suscripcion (para ayudar a identificar el sitio)."""
    extra = ["--subscription", suscripcion] if suscripcion else []
    codigo, salida = capturar([*az_cmd(), "webapp", "list", "--output", "json",
                                "--only-show-errors"] + extra)
    lista = json_tolerante(salida)
    if not isinstance(lista, list):
        return []
    return [(a.get("name"), a.get("resourceGroup")) for a in lista]


def adoptar_sitio_existente(cfg, nombre):
    """
    Reutiliza una aplicacion web que YA existe en Azure (por ejemplo
    "waf-activosfijos-cpejk6"): lee su grupo de recursos, su plan y su URL,
    los guarda en la configuracion del perfil y devuelve la config.

    Con esto el despliegue actualiza la web que ya tenes (misma URL, misma
    Neon) en vez de crear una nueva con otro sufijo.
    """
    info("Buscando la aplicacion web existente '%s'..." % nombre)
    encontrado, datos, salida = _buscar_webapp(nombre)
    if not encontrado:
        # Puede estar en otra suscripcion de la misma cuenta (p. ej. si la web
        # se creo antes de cambiar de suscripcion): se buscan en todas.
        codigo, texto = capturar([*az_cmd(), "account", "list", "--output", "json",
                                  "--only-show-errors"])
        for cuenta in (json_tolerante(texto) or []):
            sid = cuenta.get("id")
            if not sid:
                continue
            ok_encontrado, datos, _ = _buscar_webapp(nombre, sid)
            if ok_encontrado:
                aviso("La web '%s' esta en la suscripcion '%s' (no en la activa)."
                      % (nombre, cuenta.get("name")))
                encontrado = True
                break
    if not encontrado:
        existentes = _listar_webapps()
        fatal("No encontre la aplicacion web '%s' en tu cuenta de Azure.\n"
              "        Webs que si existen ahora mismo: %s\n"
              "        Revisa el nombre (va sin https:// y sin .azurewebsites.net) "
              "o despliega sin --sitio para crear una nueva."
              % (nombre, ", ".join(n for n, _ in existentes) if existentes else "(ninguna)"))
    cfg["webapp"] = nombre
    cfg["resource_group"] = datos.get("rg")
    plan = (datos.get("plan") or "").rstrip("/").split("/")[-1]
    if plan:
        cfg["app_service_plan"] = plan
    host = datos.get("host") or (nombre + ".azurewebsites.net")
    cfg["webapp_url"] = "https://%s" % host
    cfg["reutilizar_sitio"] = True
    guardar_config(cfg)
    ok("Se va a actualizar la web existente: %s" % cfg["webapp_url"])
    info("Grupo de recursos: %s | Plan: %s" % (cfg["resource_group"], cfg.get("app_service_plan")))
    return cfg


def construir_config(region, tipo_bd=TIPO_BD_NEON):
    cfg = cargar_config()
    if cfg:
        ok("Config local reutilizada (%s)." % ARCHIVO_CONFIG)
        cfg["tipo_bd"] = tipo_bd   # la eleccion del comando actual manda
        guardar_config(cfg)
        return cfg
    sufijo = sufijo_aleatorio()
    cfg = {
        "region": region,
        "tipo_bd": tipo_bd,
        "resource_group": "rg-activosfijos-" + sufijo,
        "pg_server": "pgactivos" + sufijo,
        "pg_user": PG_USUARIO,
        "pg_password": clave_fuerte(),
        "app_service_plan": "plan-activosfijos-" + sufijo,
        "webapp": "waf-activosfijos-" + sufijo,
        "jwt_secret": secrets.token_urlsafe(48),
        "creado": datetime.datetime.now().isoformat(timespec="seconds"),
    }
    guardar_config(cfg)
    info("Nombres generados para este despliegue:")
    for k in ("resource_group", "pg_server", "app_service_plan", "webapp"):
        print("        - %-18s %s" % (k + ":", cfg[k]))
    return cfg


def resolver_region_despliegue(cfg, args):
    """Consulta la directiva de regiones de la suscripcion y elige una region valida."""
    permitidas = regiones_permitidas()
    if permitidas:
        info("Regiones permitidas por la suscripcion: " + ", ".join(permitidas))
    region, candidatas = elegir_region(args.region, permitidas)
    if region != args.region:
        aviso("La region '%s' no esta permitida en esta suscripcion; uso '%s'."
              % (args.region, region))
    cfg["regiones_candidatas"] = candidatas
    guardar_config(cfg)
    return region


def flujo_completo(args):
    java_local = comprobar_requisitos()
    actualizar_gitignore()
    cfg = construir_config(args.region, args.bd)
    if getattr(args, "sitio", None):
        # La suscripcion debe estar activa ANTES de buscar la web existente:
        # 'az webapp show' solo mira la suscripcion activa.
        asegurar_login()
        elegir_suscripcion(args.suscripcion)
        cfg = adoptar_sitio_existente(cfg, args.sitio)
    if args.bd == TIPO_BD_NEON and not args.preparar:
        titulo("Base de datos: Neon (plan gratuito)")
        obtener_cadena_neon(args, cfg)

    asegurar_login()
    elegir_suscripcion(args.suscripcion)
    region = resolver_region_despliegue(cfg, args)
    runtime, java_objetivo = detectar_runtime_java(java_local)
    info("Runtime objetivo en Azure: %s (compilado con Java %d)." % (runtime, java_objetivo))

    # preparacion local (no toca Azure): primero Angular, luego backend y Maven
    preparar_frontend()
    preparar_backend(java_objetivo)
    jar = compilar_backend()
    if args.preparar:
        titulo("MODO --preparar: compilacion local terminada; no se toco Azure.")
        return

    # infraestructura + datos + despliegue
    host_pg, url_base = crear_infraestructura(cfg, region, runtime, claves_ia_cli(args))
    cargar_datos_iniciales(cfg, con_demo=not args.sin_datos_demo)
    desplegar_jar(cfg, jar, via_storage=args.via_storage, permitir_storage=not args.sin_storage)
    arranco = esperar_arranque(url_base)
    if arranco:
        cargar_datos_fabrica(cfg, url_base, con_demo=not args.sin_datos_demo)
        prueba_humo(url_base)
    resumen_final(cfg)


def flujo_solo_variables(args):
    """Vuelve a guardar en App Service las variables de entorno (IA, pagos, carpetas)."""
    cfg = cargar_config()
    if not cfg:
        fatal("Aun no existe un despliegue (no encontre %s). Ejecuta primero el despliegue completo."
              % ARCHIVO_CONFIG)
    asegurar_login()
    elegir_suscripcion(args.suscripcion)
    reaplicar_variables_entorno(cfg, claves_ia_cli(args))
    ok("Listo: la app tomara las variables en el siguiente reinicio.")


def flujo_solo_app(args):
    java_local = comprobar_requisitos()
    actualizar_gitignore()
    cfg = cargar_config()
    if not cfg and not getattr(args, "sitio", None):
        fatal("Aun no existe un despliegue (no encontre %s). Ejecuta primero el despliegue completo."
              % ARCHIVO_CONFIG)
    asegurar_login()
    if getattr(args, "sitio", None):
        cfg = cfg or {}
        cfg = adoptar_sitio_existente(cfg, args.sitio)
    elegir_suscripcion(args.suscripcion)
    runtime, java_objetivo = detectar_runtime_java(java_local)
    # Las claves de la IA pueden haber cambiado desde el ultimo despliegue.
    reaplicar_variables_entorno(cfg, claves_ia_cli(args))
    preparar_frontend()
    preparar_backend(java_objetivo)
    jar = compilar_backend()
    desplegar_jar(cfg, jar, via_storage=args.via_storage, permitir_storage=not args.sin_storage)
    if "webapp_url" in cfg:
        if esperar_arranque(cfg["webapp_url"]):
            # Tambien vuelve a sembrar y verifica los datos: asi este comando
            # sirve para "arreglar" una base que quedo a medias.
            cargar_datos_fabrica(cfg, cfg["webapp_url"], con_demo=not args.sin_datos_demo)
            prueba_humo(cfg["webapp_url"])
    resumen_final(cfg)


def flujo_estado(args):
    cfg = cargar_config()
    if not cfg:
        fatal("No hay ningun despliegue registrado en %s." % ARCHIVO_CONFIG)
    titulo("Estado del despliegue")
    print("  %-18s %s" % ("tipo_bd:", cfg.get("tipo_bd", TIPO_BD_AZURE)))
    if cfg.get("tipo_bd") == TIPO_BD_NEON:
        for k in ("neon_host", "neon_db", "neon_url"):
            if k in cfg:
                print("  %-18s %s" % (k + ":", cfg[k]))
    for k in ("resource_group", "region", "pg_server", "pg_host", "app_service_plan",
              "webapp", "webapp_url"):
        if k in cfg:
            print("  %-18s %s" % (k + ":", cfg[k]))
    if not args.dry_run:
        ejecutar([*az_cmd(), "resource", "list", "--resource-group", cfg["resource_group"],
                  "--output", "table", "--only-show-errors"])
    if "webapp_url" in cfg:
        print("\n  Abre: " + C.NEGRITA + cfg["webapp_url"] + C.RESET)


def flujo_logs(args):
    cfg = cargar_config()
    if not cfg:
        fatal("No hay ningun despliegue registrado.")
    asegurar_login()
    info("Mostrando logs en vivo (Ctrl+C para salir)...")
    sys.exit(ejecutar([*az_cmd(), "webapp", "log", "tail",
                       "--name", cfg["webapp"], "--resource-group", cfg["resource_group"],
                       "--only-show-errors"]))


def flujo_pausar(args, arrancar):
    cfg = cargar_config()
    if not cfg:
        fatal("No hay ningun despliegue registrado.")
    if cfg.get("tipo_bd") == TIPO_BD_NEON:
        info("Con Neon no hace falta pausar nada: el plan gratis suspende el computo "
             "solo tras unos minutos de inactividad y no cobra por ello.")
        ok("No se ejecuto ninguna accion (la base despierta automaticamente con la primera peticion).")
        return
    asegurar_login()
    verbo = "start" if arrancar else "stop"
    accion = "iniciando" if arrancar else "deteniendo"
    info("%s el servidor PostgreSQL (el almacenamiento sigue facturandose, no el computo)..." % accion)
    rc = ejecutar([*az_cmd(), "postgres", "flexible-server", verbo,
                   "--name", cfg["pg_server"], "--resource-group", cfg["resource_group"],
                   "--only-show-errors"])
    if rc == 0:
        ok("Listo. " + ("Ya puedes usar la app de nuevo." if arrancar else
                        "La app no podra conectarse a la BD hasta que lo reanudes."))


def flujo_eliminar(args):
    cfg = cargar_config()
    if not cfg:
        fatal("No hay ningun despliegue registrado.")
    rg = cfg["resource_group"]
    titulo("ELIMINACION DEL DESPLIEGUE")
    if cfg.get("tipo_bd") == TIPO_BD_NEON:
        aviso("Se borrara el grupo de recursos %s (App Service y plan F1). La base de datos "
              "vive en Neon: recuerda borrar tambien el proyecto desde https://console.neon.tech "
              "si quieres eliminar sus datos." % rg)
    else:
        aviso("Se borrara el grupo de recursos %s y TODO su contenido "
              "(App Service, PostgreSQL y datos)." % rg)
    if not args.confirmar:
        try:
            respuesta = input("  Escribe el nombre del grupo (%s) para confirmar: " % rg).strip()
        except EOFError:
            fatal("Confirmacion requerida (usa --confirmar para omitir la pregunta).")
        if respuesta != rg:
            fatal("Confirmacion incorrecta; no se borro nada.")
    asegurar_login()
    rc = ejecutar(az_cmd() + ["group", "delete", "--name", rg, "--yes", "--only-show-errors"])
    if rc != 0:
        fatal("No se pudo eliminar el grupo de recursos.")
    if not DRY:
        shutil.rmtree(CARPETA_CONFIG, ignore_errors=True)
    ok("Grupo %s eliminado y config local borrada. Ya no se consume credito." % rg)


def resumen_final(cfg):
    titulo("DESPLIEGUE TERMINADO")
    url = cfg.get("webapp_url", "(URL pendiente)")
    es_neon = cfg.get("tipo_bd") == TIPO_BD_NEON
    print("  Aplicacion web : " + C.NEGRITA + C.VERDE + url + C.RESET)
    print("  Grupo de recursos: %s" % cfg.get("resource_group"))
    if es_neon:
        print("  Base de datos   : Neon (plan GRATIS) en %s" % cfg.get("neon_host"))
    else:
        print("  PostgreSQL      : %s (SKU %s)" % (cfg.get("pg_server"), PG_SKU))
    print("  App Service     : plan %s (GRATIS)" % APP_SERVICE_SKU)
    print("\n  Usuarios de prueba:")
    print("    admin@uagrm.edu.bo        / admin123        (ADMINISTRADOR)")
    print("    encargado@uagrm.edu.bo    / encargado123    (ENCARGADO_ACTIVOS)")
    print("    contador@uagrm.edu.bo     / contador123     (CONTADOR)")
    print("    financiero@uagrm.edu.bo   / financiero123   (RESPONSABLE_FINANCIERO)")
    print("\n  Comandos utiles:")
    print("    python desplegar_azure.py --estado     ver recursos y URL")
    print("    python desplegar_azure.py --solo-app   publicar cambios de codigo")
    print("    python desplegar_azure.py --solo-app   (tambien vuelve a sembrar y verificar los datos)")
    print("    python desplegar_azure.py --logs       ver logs en vivo")
    if es_neon:
        print("    python desplegar_azure.py --eliminar   borrar los recursos de Azure "
              "(y borra el proyecto en la consola de Neon)")
        print(C.AMARILLO + "\n  COSTO: $0. App Service F1 gratis + Neon plan gratis. "
                          "La primera peticion tras inactividad tarda unos segundos en despertar Neon."
                          + C.RESET)
    else:
        print("    python desplegar_azure.py --pausar     detener PostgreSQL y ahorrar credito")
        print("    python desplegar_azure.py --eliminar   borrar todo")
        print(C.AMARILLO + "\n  COSTO: App Service F1 es gratis. PostgreSQL B1MS consume el credito de"
                          " Azure for Students (unos USD 15-18/mes). Usa --pausar o --eliminar para ahorrar."
                          + C.RESET)
    print("\n  Checklist (abre la web y comprueba):")
    print("    1) Entra con admin@uagrm.edu.bo / admin123")
    print("    2) Activos, Asignaciones, Inventario: deben listar datos de fabrica")
    print("    3) Presupuestos y Reportes: deben tener partidas y ejecuciones")
    print("    4) Asistente IA: 'Probar conexion' debe decir que Groq responde")
    print("    5) Respaldos: 'Descargar' debe entregar el .afb (la carpeta ya es escribible)")
    if not ajustes_ia():
        print(C.AMARILLO + "    (!) La IA quedo en MODO GUIADO: ejecuta 'python configurar_ia.py' "
                          "y luego 'python desplegar_azure.py --solo-app'." + C.RESET)


def main():
    habilitar_colores_windows()
    parser = argparse.ArgumentParser(
        description="Despliega automaticamente el Sistema de Activos Fijos en Azure (cuenta estudiantil).",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--solo-app", action="store_true", help="recompila y redespliega solo la app")
    parser.add_argument("--solo-variables", action="store_true",
                        help="vuelve a guardar las variables de entorno (IA, pagos, carpetas) sin redesplegar")
    parser.add_argument("--preparar", action="store_true", help="solo compila localmente, sin tocar Azure")
    parser.add_argument("--estado", action="store_true", help="muestra recursos y URL")
    parser.add_argument("--logs", action="store_true", help="logs en vivo de App Service")
    parser.add_argument("--pausar", action="store_true", help="detiene PostgreSQL")
    parser.add_argument("--reanudar", action="store_true", help="inicia PostgreSQL")
    parser.add_argument("--eliminar", action="store_true", help="borra el grupo de recursos completo")
    parser.add_argument("--dry-run", action="store_true", help="muestra los comandos sin ejecutarlos")
    parser.add_argument("--bd", choices=[TIPO_BD_NEON, TIPO_BD_AZURE], default=TIPO_BD_NEON,
                        help="donde alojar PostgreSQL: 'neon' (gratis, defecto) o 'azure' (consume credito)")
    parser.add_argument("--neon-cadena", help="cadena de conexion de Neon (postgresql://...); "
                                              "si se omite, se pide en consola o se lee NEON_DATABASE_URL")
    parser.add_argument("--region", default=REGION_DEFECTO,
                        help="region preferida de Azure (defecto: %s). En suscripciones de "
                             "estudiante se ignora si la directiva 'Allowed resource deployment "
                             "regions' no la permite y se elige sola una region autorizada." % REGION_DEFECTO)
    parser.add_argument("--suscripcion", help="id o nombre de la suscripcion de Azure")
    parser.add_argument("--sin-datos-demo", action="store_true", help="no carga datos ficticios")
    parser.add_argument("--confirmar", action="store_true", help="no pedir confirmacion (para --eliminar)")
    parser.add_argument("--via-storage", action="store_true",
                        help="fuerza el plan C: subir el JAR por bloques a Azure Storage y que "
                             "App Service lo descargue (sirve si tu red corta las subidas largas)")
    parser.add_argument("--sin-storage", action="store_true",
                        help="desactiva el plan C via Azure Storage (solo subidas directas)")
    parser.add_argument("--sitio", metavar="NOMBRE",
                        help="despliega en una aplicacion web que YA existe (por ejemplo "
                             "waf-activosfijos-cpejk6): reutiliza su grupo de recursos, su "
                             "plan y su URL, en vez de crear una web nueva.")
    parser.add_argument("--perfil", default=PERFIL_DEFECTO,
                        help="carpeta de perfil aislada de este despliegue (defecto: %s). "
                             "Cada perfil genera su propia web Azure y su propia Neon con sufijo propio."
                             % PERFIL_DEFECTO)
    parser.add_argument("--groq-clave", metavar="CLAVE",
                        help="clave gratuita de Groq (https://console.groq.com/keys) para la IA. "
                             "Tambien se lee de GROQ_API_KEY o de ia_config.json.")
    parser.add_argument("--gemini-clave", metavar="CLAVE",
                        help="clave gratuita de Gemini (https://aistudio.google.com/app/apikey) "
                             "para la IA. Tambien se lee de GEMINI_API_KEY o de ia_config.json.")
    args = parser.parse_args()
    global DRY
    DRY = args.dry_run
    carpeta_perfil = fijar_perfil(args.perfil)
    info("Perfil de despliegue: %s" % carpeta_perfil)

    try:
        if args.estado:
            flujo_estado(args)
        elif args.logs:
            flujo_logs(args)
        elif args.pausar:
            flujo_pausar(args, arrancar=False)
        elif args.reanudar:
            flujo_pausar(args, arrancar=True)
        elif args.eliminar:
            flujo_eliminar(args)
        elif args.solo_app:
            flujo_solo_app(args)
        elif args.solo_variables:
            flujo_solo_variables(args)
        else:
            flujo_completo(args)
    except KeyboardInterrupt:
        fatal("Cancelado por el usuario.")


if __name__ == "__main__":
    main()
