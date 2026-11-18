#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
iniciar_proyecto.py - Arranque automatico de Activos Fijos y Presupuestos (Grupo 7, UAGRM)

Hace todo lo necesario para correr el proyecto en tu maquina:
  1. Busca JDK, Maven (si falta, lo descarga portable), Node/npm y PostgreSQL.
  2. Prepara la base de datos activos_fijos_db (la crea, aplica schema.sql y los datos de prueba).
  3. Libera los puertos 8080 y 4200 si quedaron ocupados por una version vieja del proyecto.
  4. Instala las dependencias del frontend (solo la primera vez).
  5. Arranca el backend (Spring Boot) y el frontend (Angular) y abre el navegador.

Uso (o simplemente doble clic en iniciar_proyecto.bat):
    python iniciar_proyecto.py                 arranque completo
    python iniciar_proyecto.py --detener       detiene backend y frontend
    python iniciar_proyecto.py --sin-bd        no toca la base de datos
    python iniciar_proyecto.py --no-abrir      no abre el navegador
    python iniciar_proyecto.py --solo-backend | --solo-frontend
    python iniciar_proyecto.py --movil         ademas arranca la app movil (Flutter) en el dispositivo disponible
    python iniciar_proyecto.py --solo-movil    solo la app movil (el backend debe estar corriendo)
    python iniciar_proyecto.py --apk           genera el APK (ActivosFijos-SP3-movil.apk) y lo instala si hay un celular conectado
    python iniciar_proyecto.py --dispositivo ID   dispositivo para la app movil (ver: flutter devices)
    python iniciar_proyecto.py --ip 192.168.1.10  IP de tu PC para celulares/APK (por defecto se detecta)
    python iniciar_proyecto.py --sin-datos-demo    no carga datos de ejemplo
    python iniciar_proyecto.py --reinstalar    vuelve a ejecutar npm install
    python iniciar_proyecto.py --reconfigurar  vuelve a pedir la clave de PostgreSQL
    python iniciar_proyecto.py --force         no pregunta antes de cerrar procesos en los puertos

Solo usa la libreria estandar de Python 3.8+.
"""
import argparse
import getpass
import glob
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import webbrowser
import zipfile

RAIZ = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.join(RAIZ, "backend")
FRONTEND = os.path.join(RAIZ, "frontend")
MOVIL = os.path.join(RAIZ, "mobile")
DATABASE = os.path.join(RAIZ, "database")
LOGS = os.path.join(RAIZ, "logs")
TOOLS = os.path.join(RAIZ, ".tools")
CONFIG = os.path.join(RAIZ, ".local_config.json")
# Configuracion que deja el despliegue en Azure (desplegar_azure.py).
# El Sprint 3 usa un perfil aislado propio (.azure-despliegue-sp3) con otra web
# Azure y otra Neon; el de los Sprints 1/2 quedo en (.azure-despliegue).
CONFIG_AZURE_SP3 = os.path.join(RAIZ, ".azure-despliegue-sp3", "config.json")
CONFIG_AZURE = os.path.join(RAIZ, ".azure-despliegue", "config.json")

ES_WINDOWS = os.name == "nt"
DB_NAME = "activos_fijos_db"
# === Reseteo automatico de la base de datos en cada arranque ===
# True  -> cada vez que ejecutas iniciar_proyecto (o el .bat) la base se BORRA
#          y se recrea desde cero con el esquema y los datos iniciales.
# False -> comportamiento clasico: crea la base solo si falta y conserva tus datos.
# Control puntual sin tocar esta linea:
#   python iniciar_proyecto.py --resetear-bd       fuerza el borrado esta vez
#   python iniciar_proyecto.py --conservar-datos   conserva los datos aunque aqui diga True
RESETEAR_BD_CADA_INICIO = True
PUERTO_BACKEND = 8080
PUERTO_FRONTEND = 4200
MAVEN_VERSION = "3.9.9"
MAVEN_URL = "https://archive.apache.org/dist/maven/maven-3/%s/binaries/apache-maven-%s-bin.zip" % (MAVEN_VERSION, MAVEN_VERSION)

USUARIOS_PRUEBA = [
    ("ADMINISTRADOR", "admin@uagrm.edu.bo", "admin123"),
    ("ENCARGADO_ACTIVOS", "encargado@uagrm.edu.bo", "encargado123"),
    ("CONTADOR", "contador@uagrm.edu.bo", "contador123"),
    ("RESPONSABLE_FINANCIERO", "financiero@uagrm.edu.bo", "financiero123"),
]


# ----------------------------------------------------------------------------- salida

def _configurar_consola():
    for flujo in (sys.stdout, sys.stderr):
        try:
            flujo.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


def titulo(texto):
    print("\n" + "=" * 64)
    print(" " + texto)
    print("=" * 64)


def paso(texto):
    print("\n>> " + texto)


def ok(texto):
    print("   [OK]    " + texto)


def info(texto):
    print("   " + texto)


def aviso(texto):
    print("   [AVISO] " + texto)


def error(texto):
    print("   [ERROR] " + texto)


class Fallo(Exception):
    """Error que detiene el arranque con un mensaje claro."""


# ----------------------------------------------------------------------------- utilidades

def ejecutar(cmd, **kw):
    """subprocess.run con captura de texto; en Windows resuelve .cmd/.bat sin shell."""
    kw.setdefault("capture_output", True)
    kw.setdefault("text", True)
    kw.setdefault("encoding", "utf-8")
    kw.setdefault("errors", "replace")
    return subprocess.run(cmd, **kw)


def preguntar_si(pregunta, por_defecto=True, auto=False):
    if auto:
        return True
    sufijo = " [S/n] " if por_defecto else " [s/N] "
    try:
        r = input("   " + pregunta + sufijo).strip().lower()
    except EOFError:
        return por_defecto
    if not r:
        return por_defecto
    return r in ("s", "si", "sí", "y", "yes")


def cargar_config():
    base = {"db_host": "localhost", "db_port": 5432, "db_user": "postgres", "db_password": "password1234"}
    if os.path.isfile(CONFIG):
        try:
            with open(CONFIG, encoding="utf-8") as f:
                base.update(json.load(f))
        except Exception:
            aviso("No pude leer .local_config.json; uso los valores por defecto.")
    return base


def guardar_config(cfg):
    try:
        with open(CONFIG, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        aviso("No pude guardar .local_config.json: %s" % e)


# Claves de la IA (configurar_ia.bat las escribe en ia_config.json).
CONFIG_IA = os.path.join(RAIZ, "ia_config.json")
VARIABLES_IA = {
    "groq_api_key": "GROQ_API_KEY",
    "groq_modelo": "GROQ_MODEL",
    "gemini_api_key": "GEMINI_API_KEY",
    "gemini_modelo": "GEMINI_MODEL",
}


def cargar_config_ia(env):
    """Inyecta en el entorno del backend las claves de IA guardadas con
    configurar_ia.bat. Una variable ya definida en el sistema tiene prioridad,
    para no pisar una configuracion explicita del usuario."""
    if not os.path.isfile(CONFIG_IA):
        return
    try:
        with open(CONFIG_IA, encoding="utf-8") as f:
            datos = json.load(f)
    except Exception as e:
        aviso("No pude leer ia_config.json: %s" % e)
        return
    aplicadas = []
    for clave, variable in VARIABLES_IA.items():
        valor = datos.get(clave)
        if valor and not env.get(variable):
            env[variable] = str(valor)
            if clave.endswith("api_key"):
                aplicadas.append(variable.replace("_API_KEY", ""))
    if aplicadas:
        ok("IA configurada desde ia_config.json (proveedor: %s)" % ", ".join(aplicadas))


def puerto_abierto(puerto, host="127.0.0.1"):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.6)
        return s.connect_ex((host, puerto)) == 0


# Variables que guardan la pasarela de pago (configurar_pasarelas.py).
VARIABLES_PASARELA = (
    "APP_PAGOS_PROVEEDOR", "APP_URL_PUBLICA", "APP_PAGOS_SANDBOX",
    "MERCADOPAGO_ACCESS_TOKEN", "MERCADOPAGO_WEBHOOK_SECRET",
    "PAYPAL_CLIENT_ID", "PAYPAL_CLIENT_SECRET", "PAYPAL_AMBIENTE",
    "STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_MONEDA",
    "STRIPE_FACTOR_CONVERSION", "STRIPE_BASE_URL",
    "APP_PAGOS_QR_CLIENT_ID", "APP_PAGOS_QR_CLIENT_SECRET",
    "APP_PAGOS_QR_ID_ESTABLECIMIENTO", "APP_PAGOS_QR_NOMBRE_ESTABLECIMIENTO",
    "APP_PAGOS_QR_BASE_URL", "APP_PAGOS_QR_WEBHOOK_KEY", "APP_PAGOS_QR_WEBHOOK_VALUE",
    "APP_PAGOS_QR_VIGENCIA", "APP_PAGOS_MONEDA", "APP_PAGOS_FACTOR_CONVERSION",
)


def cargar_pasarelas_env(env):
    """Inyecta en el entorno del backend las credenciales de la pasarela de pago
    guardadas por configurar_pasarelas.py en "pasarelas.env" (archivo KEY=VALUE).
    Una variable ya definida en el sistema tiene prioridad, para no pisar una
    configuracion explicita del usuario. Asi, al probar en local, el backend
    usa las mismas claves que pusiste en Azure."""
    ruta = os.path.join(RAIZ, "pasarelas.env")
    if not os.path.isfile(ruta):
        return
    try:
        with open(ruta, encoding="utf-8") as f:
            lineas = f.readlines()
    except OSError as e:
        aviso("No pude leer pasarelas.env: %s" % e)
        return
    aplicadas = []
    for linea in lineas:
        linea = linea.strip()
        if not linea or linea.startswith("#") or "=" not in linea:
            continue
        clave, valor = linea.split("=", 1)
        clave = clave.strip()
        valor = valor.strip().strip('"').strip("'")
        if clave in VARIABLES_PASARELA and valor and not env.get(clave):
            env[clave] = valor
            aplicadas.append(clave)
    if aplicadas:
        ok("Pasarela de pago: %s (desde pasarelas.env)" % ", ".join(aplicadas))
        info("Para probar el webhook en local, la pasarela debe poder llamar a esta maquina.")
    else:
        info("Sin credenciales de pasarela en pasarelas.env (la pantalla de suscripcion avisara).")

def http_responde(url, timeout=3):
    """True si el servidor contesta cualquier codigo HTTP (aunque sea 401/403)."""
    try:
        urllib.request.urlopen(url, timeout=timeout)
        return True
    except urllib.error.HTTPError:
        return True
    except Exception:
        return False


def calcular_depreciacion(puerto, timeout=180):
    """
    Pide al backend el calculo de la depreciacion para que la tabla
    depreciacion_activo no quede vacia (el calculo automatico corre al
    arrancar, cuando todavia no hay activos sembrados).
    """
    base = "http://127.0.0.1:%d/api" % puerto
    # El Super Admin calcula sin empresa: asi la depreciacion se genera para
    # TODAS las empresas (cada una con su propio tenant).
    credenciales = [("superadmin@plataforma.local", "Cambiar123!"),
                    ("admin@uagrm.edu.bo", "admin123")]
    try:
        token = ""
        for correo, clave in credenciales:
            peticion = urllib.request.Request(
                base + "/auth/login",
                data=json.dumps({"correo": correo, "password": clave}).encode(),
                headers={"Content-Type": "application/json"}, method="POST")
            with urllib.request.urlopen(peticion, timeout=20) as respuesta:
                token = json.loads(respuesta.read().decode()).get("token", "")
            if token:
                break
        if not token:
            return False
        peticion = urllib.request.Request(
            base + "/depreciacion/calcular", data=b"",
            headers={"Authorization": "Bearer " + token}, method="POST")
        with urllib.request.urlopen(peticion, timeout=timeout) as respuesta:
            return respuesta.getcode() == 200
    except Exception as exc:
        aviso("No se pudo calcular la depreciacion (%s); la tabla quedara vacia." % exc)
        return False


def leer_cola(ruta, lineas=40):
    if not os.path.isfile(ruta):
        return ""
    with open(ruta, "rb") as f:
        datos = f.read()
    if datos[:2] in (b"\xff\xfe", b"\xfe\xff"):
        texto = datos.decode("utf-16", errors="replace")
    else:
        texto = datos.decode("utf-8", errors="replace")
    return "\n".join(texto.replace("\r", "").splitlines()[-lineas:])


# ----------------------------------------------------------------------------- herramientas

def version_java(java_exe):
    try:
        r = ejecutar([java_exe, "-version"])
    except Exception:
        return None
    m = re.search(r'version "(\d+)(?:\.(\d+))?', (r.stderr or "") + (r.stdout or ""))
    if not m:
        return None
    mayor = int(m.group(1))
    return int(m.group(2) or 0) if mayor == 1 else mayor


def candidatos_java():
    homes = []
    if os.environ.get("JAVA_HOME"):
        homes.append(os.environ["JAVA_HOME"])
    usuario = os.environ.get("USERPROFILE") or os.path.expanduser("~")
    patrones = [os.path.join(usuario, ".jdk", "*"), os.path.join(usuario, ".jdks", "*")]
    if ES_WINDOWS:
        for base in (os.environ.get("ProgramFiles", r"C:\Program Files"), os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")):
            for sub in ("Eclipse Adoptium", "Java", "Microsoft", "Amazon Corretto", "Zulu", "BellSoft", "Semeru"):
                patrones.append(os.path.join(base, sub, "*"))
    else:
        patrones += ["/usr/lib/jvm/*", "/Library/Java/JavaVirtualMachines/*/Contents/Home"]
    for p in patrones:
        homes += glob.glob(p)
    java_en_path = shutil.which("java")
    if java_en_path:
        homes.append(os.path.dirname(os.path.dirname(os.path.realpath(java_en_path))))
    vistos, resultado = set(), []
    exe = "java.exe" if ES_WINDOWS else "java"
    javac = "javac.exe" if ES_WINDOWS else "javac"
    for h in homes:
        h = os.path.normpath(h)
        if h in vistos:
            continue
        vistos.add(h)
        if os.path.isfile(os.path.join(h, "bin", exe)) and os.path.isfile(os.path.join(h, "bin", javac)):
            v = version_java(os.path.join(h, "bin", exe))
            if v:
                resultado.append((v, h))
    return resultado


def buscar_java():
    candidatos = [c for c in candidatos_java() if c[0] >= 17]
    if not candidatos:
        raise Fallo("No encontre un JDK 17 o superior (con javac).\n"
                    "   Instalalo con:  winget install EclipseAdoptium.Temurin.25.JDK\n"
                    "   o descargalo de https://adoptium.net/ y vuelve a ejecutar este archivo.")
    candidatos.sort(key=lambda c: c[0], reverse=True)
    return candidatos[0]


def buscar_maven():
    mvn = shutil.which("mvn")
    if mvn:
        return mvn
    nombre = "mvn.cmd" if ES_WINDOWS else "mvn"
    local = os.path.join(TOOLS, "apache-maven-%s" % MAVEN_VERSION, "bin", nombre)
    if os.path.isfile(local):
        return local
    aviso("Maven no esta instalado. Lo descargo en forma portable (una sola vez, ~9 MB)...")
    os.makedirs(TOOLS, exist_ok=True)
    zip_ruta = os.path.join(TOOLS, "maven.zip")
    try:
        urllib.request.urlretrieve(MAVEN_URL, zip_ruta)
        with zipfile.ZipFile(zip_ruta) as z:
            z.extractall(TOOLS)
        os.remove(zip_ruta)
    except Exception as e:
        raise Fallo("No pude descargar Maven (%s).\n   Instalalo con:  winget install Apache.Maven" % e)
    if not ES_WINDOWS:
        os.chmod(local, 0o755)
    if not os.path.isfile(local):
        raise Fallo("La descarga de Maven no dejo el ejecutable esperado en " + local)
    ok("Maven %s listo en .tools" % MAVEN_VERSION)
    return local


def buscar_node():
    node, npm = shutil.which("node"), shutil.which("npm")
    if not node or not npm:
        raise Fallo("No encontre Node.js / npm.\n   Instalalo con:  winget install OpenJS.NodeJS.LTS\n   o desde https://nodejs.org/")
    return node, npm


def buscar_psql():
    psql = shutil.which("psql")
    if psql:
        return psql
    if ES_WINDOWS:
        for base in (os.environ.get("ProgramFiles", r"C:\Program Files"), os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")):
            hallados = sorted(glob.glob(os.path.join(base, "PostgreSQL", "*", "bin", "psql.exe")), reverse=True)
            if hallados:
                return hallados[0]
    return None


# ----------------------------------------------------------------------------- puertos

def _pids_por_proc(puerto):
    """Linux sin lsof/ss: busca el proceso que escucha en el puerto leyendo /proc."""
    inodos = set()
    for tabla in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            with open(tabla) as f:
                next(f)
                for linea in f:
                    c = linea.split()
                    if len(c) > 9 and c[3] == "0A" and int(c[1].rsplit(":", 1)[1], 16) == puerto:
                        inodos.add(c[9])
        except Exception:
            pass
    pids = set()
    if not inodos:
        return pids
    for d in glob.glob("/proc/[0-9]*"):
        try:
            for fd in os.listdir(d + "/fd"):
                try:
                    destino = os.readlink("%s/fd/%s" % (d, fd))
                except OSError:
                    continue
                if destino.startswith("socket:[") and destino[8:-1] in inodos:
                    pids.add(int(os.path.basename(d)))
        except OSError:
            continue
    return pids


def pids_en_puerto(puerto):
    pids = set()
    try:
        if ES_WINDOWS:
            r = ejecutar(["netstat", "-ano", "-p", "TCP"])
            for linea in r.stdout.splitlines():
                partes = linea.split()
                if len(partes) >= 5 and partes[3].upper() == "LISTENING" and partes[1].rsplit(":", 1)[-1] == str(puerto):
                    pids.add(int(partes[4]))
        else:
            if shutil.which("lsof"):
                r = ejecutar(["lsof", "-t", "-iTCP:%d" % puerto, "-sTCP:LISTEN"])
                pids |= {int(x) for x in r.stdout.split() if x.isdigit()}
            if not pids and shutil.which("ss"):
                r = ejecutar(["ss", "-ltnp"])
                for linea in r.stdout.splitlines():
                    if re.search(r":%d\s" % puerto, linea):
                        pids |= {int(x) for x in re.findall(r"pid=(\d+)", linea)}
            if not pids and os.path.isdir("/proc/net"):
                pids |= _pids_por_proc(puerto)
            if not pids and shutil.which("fuser"):
                r = ejecutar(["fuser", "%d/tcp" % puerto])
                pids |= {int(x) for x in re.findall(r"\d+", r.stdout)}
    except Exception:
        pass
    pids.discard(0)
    return sorted(pids)


def matar_pid(pid):
    try:
        if ES_WINDOWS:
            ejecutar(["taskkill", "/PID", str(pid), "/T", "/F"])
        else:
            os.kill(pid, 15)
    except Exception:
        pass


def liberar_puerto(puerto, nombre, auto):
    if not puerto_abierto(puerto):
        return
    pids = pids_en_puerto(puerto)
    aviso("El puerto %d (%s) ya esta en uso%s." % (puerto, nombre, " por el PID " + ", ".join(map(str, pids)) if pids else ""))
    info("Probablemente es una version anterior del proyecto que sigue corriendo (por eso no veias los cambios).")
    if not pids:
        raise Fallo("No pude identificar el proceso. Cierralo a mano y vuelve a ejecutar.")
    if not preguntar_si("¿Detenerlo para arrancar la version nueva?", True, auto):
        raise Fallo("El puerto %d sigue ocupado." % puerto)
    for pid in pids:
        matar_pid(pid)
    for _ in range(20):
        if not puerto_abierto(puerto):
            break
        time.sleep(0.5)
    if puerto_abierto(puerto):
        raise Fallo("No pude liberar el puerto %d. Cierra ese programa manualmente." % puerto)
    ok("Puerto %d liberado" % puerto)


def detener():
    titulo("Deteniendo backend y frontend")
    for puerto, nombre in ((PUERTO_BACKEND, "backend"), (PUERTO_FRONTEND, "frontend")):
        pids = pids_en_puerto(puerto)
        if not pids:
            info("%s (puerto %d): no estaba en ejecucion" % (nombre, puerto))
            continue
        for pid in pids:
            matar_pid(pid)
        time.sleep(1)
        ok("%s (puerto %d) detenido" % (nombre, puerto)) if not puerto_abierto(puerto) else aviso("%s sigue activo" % nombre)
    return 0


# ----------------------------------------------------------------------------- base de datos

class BaseDatos:
    def __init__(self, psql, cfg):
        self.psql, self.cfg = psql, cfg

    def _cmd(self, db, extra):
        return [self.psql, "-h", str(self.cfg["db_host"]), "-p", str(self.cfg["db_port"]), "-U", self.cfg["db_user"],
                "-d", db, "-X", "-q", "-v", "ON_ERROR_STOP=1"] + extra

    def _env(self):
        env = os.environ.copy()
        env["PGPASSWORD"] = str(self.cfg["db_password"])
        env["PGCLIENTENCODING"] = "UTF8"
        return env

    def sql(self, consulta, db=DB_NAME):
        return ejecutar(self._cmd(db, ["-tA", "-c", consulta]), env=self._env())

    def archivo(self, ruta, db=DB_NAME):
        return ejecutar(self._cmd(db, ["-f", ruta]), env=self._env())

    def valor(self, consulta, db=DB_NAME):
        r = self.sql(consulta, db)
        if r.returncode != 0:
            return None
        return r.stdout.strip()


def preparar_base_datos(psql, cfg, args):
    if not psql:
        raise Fallo("No encontre 'psql' (cliente de PostgreSQL).\n"
                    "   Instala PostgreSQL desde https://www.postgresql.org/download/windows/ y agrega su carpeta bin al PATH,\n"
                    "   o ejecuta con --sin-bd si tu base ya esta lista.")
    bd = BaseDatos(psql, cfg)
    intentos = 0
    while True:
        r = bd.sql("SELECT 1", "postgres")
        if r.returncode == 0:
            break
        msg = (r.stderr or "").lower()
        if "password" in msg or "autenticaci" in msg or "authentication" in msg:
            intentos += 1
            if intentos > 3:
                raise Fallo("No pude autenticarme en PostgreSQL con el usuario %s." % cfg["db_user"])
            aviso("Clave de PostgreSQL incorrecta para el usuario '%s'." % cfg["db_user"])
            try:
                cfg["db_password"] = getpass.getpass("   Escribi la clave del usuario %s (no se muestra): " % cfg["db_user"])
            except EOFError:
                raise Fallo("Se necesita la clave de PostgreSQL (usa --reconfigurar en una consola interactiva).")
            continue
        if "could not connect" in msg or "connection refused" in msg or "no se pudo conectar" in msg or "refused" in msg:
            raise Fallo("PostgreSQL no esta en ejecucion en %s:%s.\n"
                        "   Inicia el servicio (Windows: Servicios -> postgresql-x64-XX -> Iniciar) y vuelve a ejecutar." % (cfg["db_host"], cfg["db_port"]))
        raise Fallo("No pude conectar con PostgreSQL:\n   " + (r.stderr or "").strip())
    guardar_config(cfg)
    ok("Conectado a PostgreSQL (%s@%s:%s)" % (cfg["db_user"], cfg["db_host"], cfg["db_port"]))

    # El reseteo puede apagarse con --conservar-datos o forzarse con --resetear-bd.
    resetear = getattr(args, "resetear_bd", False) or (
        RESETEAR_BD_CADA_INICIO and not getattr(args, "conservar_datos", False))
    if resetear:
        info("Reseteo activado: se borrara la base %s y se recreara desde cero..." % DB_NAME)
        # Cierra conexiones de un backend de un arranque anterior antes del DROP.
        r = bd.sql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                   "WHERE datname = '%s' AND pid <> pg_backend_pid()" % DB_NAME, "postgres")
        if r.returncode != 0:
            raise Fallo("No pude cerrar las conexiones activas a %s:\n   %s"
                        % (DB_NAME, (r.stderr or "").strip()))
        r = bd.sql("DROP DATABASE IF EXISTS %s" % DB_NAME, "postgres")
        if r.returncode != 0:
            raise Fallo("No pude borrar la base de datos %s:\n   %s" % (DB_NAME, (r.stderr or "").strip()))
        r = bd.sql("CREATE DATABASE %s" % DB_NAME, "postgres")
        if r.returncode != 0:
            raise Fallo("No pude recrear la base de datos %s:\n   %s" % (DB_NAME, (r.stderr or "").strip()))
        ok("Base de datos %s borrada y recreada desde cero" % DB_NAME)
    else:
        existe = bd.valor("SELECT 1 FROM pg_database WHERE datname = '%s'" % DB_NAME, "postgres")
        if existe != "1":
            r = bd.sql("CREATE DATABASE %s" % DB_NAME, "postgres")
            if r.returncode != 0:
                raise Fallo("No pude crear la base de datos %s:\n   %s" % (DB_NAME, (r.stderr or "").strip()))
            ok("Base de datos %s creada" % DB_NAME)
        else:
            ok("Base de datos %s encontrada (se conservan los datos)" % DB_NAME)

    # Con la base recien creada todos los scripts se aplican si o si; sin reseteo
    # se mantienen las guardas originales para no repetir datos.
    if resetear or bd.valor("SELECT to_regclass('public.usuario') IS NOT NULL") != "t":
        r = bd.archivo(os.path.join(DATABASE, "schema.sql"))
        if r.returncode != 0:
            raise Fallo("Fallo schema.sql:\n   " + (r.stderr or "").strip())
        ok("Esquema inicial creado (schema.sql)")
    # IMPORTANTE: las semillas NO se aplican aqui. Todavia no existen las
    # columnas empresa_id ni las tablas de los Sprints 2 y 3: las crea el
    # backend al arrancar (Hibernate + migraciones V3/V4). Si se siembra antes,
    # el script falla ("column empresa_id does not exist") y la aplicacion
    # queda con las tablas vacias. Las semillas se aplican despues de que el
    # backend este listo (ver cargar_datos_fabrica).
    return bd


# Tablas de negocio que SIEMPRE deben quedar con datos ficticios de fabrica.
TABLAS_OBLIGATORIAS = [
    "empresa", "cuenta", "plan", "suscripcion", "pago", "configuracion_empresa",
    "rol", "rol_permiso", "permiso", "usuario", "categoria", "area",
    "ubicacion", "activo", "asignacion", "historial_estado_activo",
    "mantenimiento", "depreciacion_activo", "presupuesto",
    "partida_presupuestaria", "ejecucion_presupuestaria",
    "verificacion_inventario", "consulta_guardada", "respaldo",
    "programacion_respaldo", "bitacora_auditoria",
]


def esperar_esquema_listo(bd, segundos=150):
    """Espera a que el backend termine la migracion V3 y los inicializadores.

    El puerto HTTP responde ANTES de que corran los ApplicationRunner
    (migracion V3 y siembra de roles, permisos y areas): si los seeds SQL
    llegaban antes, sus consultas fallaban (tabla inexistente), la guarda
    devolvia None y la siembra se omitia en silencio, dejando tablas vacias.
    """
    prueba = ("SELECT to_regclass('public.pago') IS NOT NULL "
              "AND (SELECT count(*) FROM rol) > 0 "
              "AND (SELECT count(*) FROM area) > 0 "
              "AND (SELECT count(*) FROM categoria) > 0")
    inicio = time.time()
    while time.time() - inicio < segundos:
        try:
            if bd.valor(prueba) == "t":
                return True
        except Exception:
            pass
        time.sleep(2)
    return False


def _contar_tabla(bd, tabla):
    try:
        return int(bd.valor("SELECT count(*) FROM %s" % tabla))
    except (TypeError, ValueError):
        return -1


def cargar_datos_fabrica(bd):
    """Aplica los seeds post-arranque cuando el backend ya esta listo.

    Sprint 2: presupuestos base, partidas y mantenimiento.
    Sprint 3: rellena TODAS las tablas de negocio (asignaciones, historial,
    mantenimientos, ejecuciones, pagos, inventario, consultas, respaldos y
    bitacora). Cada script es idempotente; si falla porque el esquema aun no
    existe, se reintenta en vez de saltarse la carga.
    """
    paso("Cargando datos ficticios de fabrica en todas las tablas")
    if not esperar_esquema_listo(bd):
        aviso("El backend no marco el esquema como listo a tiempo; reintento la carga de todas formas.")
    scripts = [
        # 1) Los usuarios de prueba: necesitan los roles y la empresa demo, que
        #    crea el backend al arrancar.
        ("fix_usuarios_prueba.sql", "usuarios de prueba (con su cuenta global)"),
        # 2) Los datos del Sprint 1 (activos, ubicaciones): necesitan la
        #    columna empresa_id, que agrega la migracion V3 del backend.
        ("seed_datos_ficticios.sql", "activos y ubicaciones de ejemplo"),
        ("seed_sprint2_datos.sql", "presupuestos base, partidas y mantenimiento"),
        ("seed_sprint3_datos.sql", "datos completos del Sprint 3 (todas las tablas)"),
        ("seed_multiempresa_datos.sql",
         "cuentas globales, segunda empresa y membresia cruzada (multiempresa)"),
    ]
    for nombre, descripcion in scripts:
        ruta = os.path.join(DATABASE, nombre)
        cargado = False
        detalle = ""
        for intento in (1, 2, 3):
            r = bd.archivo(ruta)
            if r.returncode == 0:
                cargado = True
                break
            detalle = (r.stderr or "").strip()[:220]
            aviso("Intento %d de %s fallido: %s" % (intento, nombre, detalle))
            time.sleep(3)
        if cargado:
            ok("Datos de fabrica cargados: %s (%s)" % (nombre, descripcion))
        else:
            aviso("No se pudo cargar %s. Puedes aplicarlo a mano con psql o volver a abrir iniciar_proyecto.bat" % nombre)
    # La depreciacion se calcula con los activos ya sembrados (si se pide antes,
    # el calculo automatico del arranque no encuentra nada).
    if calcular_depreciacion(PUERTO_BACKEND):
        ok("Depreciacion calculada para los activos de fabrica.")
    return verificar_datos_de_fabrica(bd)


def verificar_datos_de_fabrica(bd):
    """Conteo final de cada tabla; alerta si alguna quedo vacia."""
    vacias, resumen = [], []
    for tabla in TABLAS_OBLIGATORIAS:
        n = _contar_tabla(bd, tabla)
        if n < 0:
            continue  # la tabla aun no existe: el backend no termino de inicializar
        resumen.append((tabla, n))
        if n == 0:
            vacias.append(tabla)
    if resumen:
        info("Resumen de datos de fabrica:")
        for tabla, n in resumen:
            print("        %-28s %5d filas" % (tabla, n))
    if vacias:
        aviso("Tablas sin datos de fabrica: %s. Vuelve a ejecutar iniciar_proyecto.bat." % ", ".join(vacias))
    else:
        ok("Las %d tablas de negocio tienen datos ficticios de fabrica." % len(resumen))
    return vacias


# ----------------------------------------------------------------------------- procesos

def _ps_quote(texto):
    return "'" + texto.replace("'", "''") + "'"


def lanzar(nombre, cmd_lista, cwd, env, log):
    """Arranca un servicio. En Windows abre una consola visible que ademas guarda el log."""
    os.makedirs(LOGS, exist_ok=True)
    if os.path.isfile(log):
        try:
            os.remove(log)
        except OSError:
            pass
    if ES_WINDOWS:
        cmd_ps = "$Host.UI.RawUI.WindowTitle = %s; & %s 2>&1 | Tee-Object -FilePath %s" % (
            _ps_quote(nombre), " ".join(_ps_quote(c) for c in cmd_lista), _ps_quote(log))
        return subprocess.Popen(["powershell", "-NoProfile", "-Command", cmd_ps], cwd=cwd, env=env,
                                creationflags=subprocess.CREATE_NEW_CONSOLE)
    salida = open(log, "wb")
    return subprocess.Popen(cmd_lista, cwd=cwd, env=env, stdout=salida, stderr=subprocess.STDOUT, start_new_session=True)


def esperar_servicio(nombre, proceso, log, url, limite_s, marcas_error, marca_ok=None):
    inicio = time.time()
    ultimo_aviso = 0
    while time.time() - inicio < limite_s:
        if proceso.poll() is not None:
            error("%s se cerro inesperadamente (codigo %s). Ultimas lineas del log:" % (nombre, proceso.returncode))
            print("\n".join("      " + l for l in leer_cola(log, 45).splitlines()))
            return False
        cola = leer_cola(log, 80)
        for marca in marcas_error:
            if marca in cola:
                error("%s no pudo iniciar. Detalle del log (%s):" % (nombre, log))
                print("\n".join("      " + l for l in cola.splitlines()[-45:]))
                return False
        if http_responde(url) or (marca_ok and marca_ok in cola and puerto_abierto(PUERTO_BACKEND)):
            return True
        transcurrido = int(time.time() - inicio)
        if transcurrido - ultimo_aviso >= 15:
            ultimo_aviso = transcurrido
            ultima = [l for l in cola.splitlines() if l.strip()]
            info("... %s arrancando (%ds)%s" % (nombre, transcurrido, (" - " + ultima[-1].strip()[:90]) if ultima else ""))
        time.sleep(2)
    error("%s no respondio en %d segundos. Revisa el log: %s" % (nombre, limite_s, log))
    return False


# ----------------------------------------------------------------------------- app movil (Flutter)

def buscar_flutter():
    exe = shutil.which("flutter")
    if exe:
        return exe
    home = os.environ.get("USERPROFILE") or os.path.expanduser("~")
    bases = [os.path.join(home, "flutter"), os.path.join(home, "dev", "flutter"), os.path.join(home, "development", "flutter"),
             os.path.join(home, "sdk", "flutter"), os.path.join(home, "snap", "flutter", "common", "flutter")]
    if ES_WINDOWS:
        bases += [r"C:\src\flutter", r"C:\flutter", r"C:\tools\flutter", r"C:\dev\flutter"]
    else:
        bases += ["/opt/flutter", "/usr/local/flutter"]
    nombre = "flutter.bat" if ES_WINDOWS else "flutter"
    for base in bases:
        candidato = os.path.join(base, "bin", nombre)
        if os.path.isfile(candidato):
            return candidato
    raise Fallo("No encontre Flutter (necesario solo para la app movil).\n"
                "   Instalalo desde https://docs.flutter.dev/get-started/install y agrega flutter\\bin al PATH,\n"
                "   o ejecuta sin --movil para correr solo el backend y la web.")


def buscar_adb():
    exe = shutil.which("adb")
    if exe:
        return exe
    nombre = "adb.exe" if ES_WINDOWS else "adb"
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    candidatos = []
    if sdk:
        candidatos.append(os.path.join(sdk, "platform-tools", nombre))
    if ES_WINDOWS:
        candidatos.append(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk", "platform-tools", nombre))
    else:
        candidatos.append(os.path.expanduser("~/Android/Sdk/platform-tools/" + nombre))
    for c in candidatos:
        if os.path.isfile(c):
            return c
    return None


def ip_lan():
    for destino in ("8.8.8.8", "10.255.255.255"):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect((destino, 80))
                ip = s.getsockname()[0]
                if ip and not ip.startswith("127."):
                    return ip
        except Exception:
            continue
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return None


def listar_dispositivos(flutter, env):
    r = ejecutar([flutter, "devices", "--machine"], env=env, timeout=180)
    texto = r.stdout or ""
    ini, fin = texto.find("["), texto.rfind("]")
    if ini < 0 or fin < ini:
        return []
    try:
        return json.loads(texto[ini:fin + 1])
    except Exception:
        return []


def elegir_dispositivo(dispositivos, preferido):
    if preferido:
        for d in dispositivos:
            if d.get("id") == preferido or preferido.lower() in str(d.get("name", "")).lower():
                return d
        raise Fallo("No encontre el dispositivo '%s'. Dispositivos disponibles: %s" % (
            preferido, ", ".join(str(d.get("id")) for d in dispositivos) or "ninguno"))

    def plataforma(d):
        return str(d.get("targetPlatform", ""))

    orden = [
        lambda d: plataforma(d).startswith("android") and not d.get("emulator"),   # celular conectado
        lambda d: plataforma(d).startswith("android"),                             # emulador Android
        lambda d: d.get("id") == "windows",
        lambda d: d.get("id") == "chrome",
        lambda d: d.get("id") == "edge",
        lambda d: d.get("id") in ("macos", "linux"),
        lambda d: True,
    ]
    for criterio in orden:
        for d in dispositivos:
            if criterio(d):
                return d
    raise Fallo("Flutter no encontro ningun dispositivo.\n"
                "   Conecta un celular con depuracion USB, abre un emulador Android o habilita Windows/Chrome:\n"
                "     flutter devices   |   flutter emulators --launch <id>   |   flutter config --enable-windows-desktop")


def url_api_para(dispositivo, ip_manual, adb):
    """URL del backend segun donde corre la app movil."""
    plat = str(dispositivo.get("targetPlatform", ""))
    base = "http://%s:%d/api"
    if plat.startswith("android"):
        if dispositivo.get("emulator"):
            return base % ("10.0.2.2", PUERTO_BACKEND), "emulador Android"
        if adb and not ip_manual:
            r = ejecutar([adb, "-s", str(dispositivo.get("id")), "reverse", "tcp:%d" % PUERTO_BACKEND, "tcp:%d" % PUERTO_BACKEND])
            if r.returncode == 0:
                return base % ("localhost", PUERTO_BACKEND), "celular por USB (adb reverse, sin depender de la WiFi)"
        ip = ip_manual or ip_lan()
        if not ip:
            raise Fallo("No pude detectar la IP de tu PC. Indicala con --ip 192.168.X.X")
        return base % (ip, PUERTO_BACKEND), "celular por WiFi (IP de tu PC: %s)" % ip
    if plat.startswith("ios"):
        ip = ip_manual or ip_lan() or "localhost"
        return base % (ip, PUERTO_BACKEND), "iPhone/iPad (IP de tu PC: %s)" % ip
    return base % ("localhost", PUERTO_BACKEND), "escritorio/navegador"


CLAVE_MODO_DESARROLLADOR = (
    r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
)


def modo_desarrollador_windows():
    """
    Indica si el 'Modo de programador' de Windows esta activado (True/False).
    En sistemas que no son Windows devuelve None (no aplica). Flutter exige ese
    modo en Windows para crear los symlinks que usan los plugins.
    """
    if not ES_WINDOWS:
        return None
    try:
        r = subprocess.run(["reg", "query", CLAVE_MODO_DESARROLLADOR,
                            "/v", "AllowDevelopmentWithoutDevLicense"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        salida = (r.stdout.decode("utf-8", "replace")
                  + r.stderr.decode("utf-8", "replace")).lower()
        if r.returncode == 0 and "0x1" in salida:
            return True
    except (OSError, subprocess.SubprocessError):
        pass
    return False


def asegurar_modo_desarrollador():
    """Falla pronto y con instrucciones exactas si Windows no permite symlinks."""
    if not ES_WINDOWS or modo_desarrollador_windows():
        return
    raise Fallo(
        "El 'Modo de programador' de Windows esta DESACTIVADO. Flutter lo necesita para\n"
        "  crear los enlaces (symlinks) de los plugins (printing, share_plus, path_provider...).\n"
        "  Elige una de estas opciones y vuelve a ejecutar el mismo comando:\n"
        "    1) Doble clic en Habilitar_modo_desarrollador.bat (pide permiso de administrador).\n"
        "    2) A mano: ejecuta  start ms-settings:developers  y activa 'Modo de programador'.\n"
        "    3) En una consola como administrador:\n"
        "       reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AppModelUnlock\"\n"
        "         /t REG_DWORD /f /v AllowDevelopmentWithoutDevLicense /d 1")


def pub_get(flutter, env):
    asegurar_modo_desarrollador()
    paso("Preparando la app movil (flutter pub get)")
    r = subprocess.run([flutter, "pub", "get"], cwd=MOVIL, env=env)
    if r.returncode != 0:
        # El caso mas frecuente en Windows: symlinks sin Modo de programador
        if ES_WINDOWS and not modo_desarrollador_windows():
            raise Fallo(
                "flutter pub get fallo por los symlinks de plugins: activa el 'Modo de\n"
                "  programador' de Windows con Habilitar_modo_desarrollador.bat (o\n"
                "  'start ms-settings:developers') y vuelve a ejecutar el comando.")
        raise Fallo("flutter pub get fallo. Ejecuta 'flutter doctor' para revisar tu instalacion.")
    ok("Dependencias de la app movil listas")


def aviso_firewall(url):
    if "localhost" in url or "10.0.2.2" in url:
        return
    info("Para que el celular llegue al backend por WiFi: misma red que tu PC y puerto %d permitido en el firewall." % PUERTO_BACKEND)
    if ES_WINDOWS:
        info("  (como administrador)  netsh advfirewall firewall add rule name=\"Activos 8080\" dir=in action=allow protocol=TCP localport=%d" % PUERTO_BACKEND)


def iniciar_movil(args, env):
    flutter = buscar_flutter()
    ok("Flutter: " + flutter)
    if not puerto_abierto(PUERTO_BACKEND):
        aviso("El backend no responde en el puerto %d: la app movil abrira pero no podra iniciar sesion." % PUERTO_BACKEND)
        info("Ejecuta iniciar_proyecto.bat (sin --solo-movil) para levantarlo.")
    pub_get(flutter, env)
    paso("Buscando dispositivo para la app movil")
    dispositivos = listar_dispositivos(flutter, env)
    dispositivo = elegir_dispositivo(dispositivos, args.dispositivo)
    adb = buscar_adb()
    url, descripcion = url_api_para(dispositivo, args.ip, adb)
    ok("Dispositivo: %s (%s) - %s" % (dispositivo.get("name"), dispositivo.get("id"), descripcion))
    ok("La app usara el backend en " + url)
    aviso_firewall(url)
    paso("Arrancando la app movil (la primera compilacion tarda varios minutos)")
    log = os.path.join(LOGS, "movil.log")
    proc = lanzar("Movil - Flutter", [flutter, "run", "-d", str(dispositivo.get("id")), "--dart-define=API_URL=" + url], MOVIL, env, log)
    for _ in range(15):
        time.sleep(2)
        if proc.poll() is not None:
            error("flutter run termino (codigo %s). Ultimas lineas del log:" % proc.returncode)
            print("\n".join("      " + l for l in leer_cola(log, 40).splitlines()))
            raise Fallo("La app movil no arranco. Detalle en logs\\movil.log")
    ok("App movil compilando/ejecutandose (ventana 'Movil - Flutter', log en logs\\movil.log)")


def normalizar_url_api(url):
    """
    Normaliza una URL de backend para el --dart-define=API_URL de Flutter.
    Acepta 'https://h.azurewebsites.net' o '.../api/' y devuelve siempre
    'https://h.azurewebsites.net/api' (sin barra final; el cliente concatena
    rutas como '/auth/login'). Lanza Fallo si el valor no es http(s).
    """
    url = (url or "").strip().rstrip("/")
    if not url.startswith(("http://", "https://")):
        raise Fallo("La URL del backend debe empezar por http:// o https:// (recibido: %s)" % url)
    if not url.rstrip("/").endswith("/api"):
        url = url + "/api"
    return url


def url_azure_desde_config():
    """
    Si el proyecto ya se desplego en Azure, devuelve la URL publica del backend
    (.../api). None si no hay despliegue.

    El despliegue del Sprint 3 usa el perfil aislado ".azure-despliegue-sp3"
    (otra web Azure y otra Neon propias); el de los Sprints 1/2 usa
    ".azure-despliegue". Se busca primero el del Sprint 3, que es el vigente,
    y se cae al anterior si no existe.
    """
    for carpeta in (CONFIG_AZURE_SP3, CONFIG_AZURE):
        if not os.path.isfile(carpeta):
            continue
        try:
            with open(carpeta, "r", encoding="utf-8") as f:
                datos = json.load(f)
            webapp_url = datos.get("webapp_url")
            if webapp_url:
                return normalizar_url_api(webapp_url)
        except (OSError, ValueError) as e:
            aviso("No pude leer la config de Azure (%s); seguire con la URL local." % e)
    return None


def revisar_toolchain_android(flutter):
    """
    Avisa (sin bloquear) si flutter doctor detecta cmdline-tools faltantes o
    licencias sin aceptar. La compilacion puede funcionar igual si Android
    Studio ya dejo las licencias aceptadas; si fallara, el aviso dice como arreglarlo.
    """
    if not ES_WINDOWS:
        return
    try:
        r = subprocess.run([flutter, "doctor"], stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=120)
        salida = r.stdout.decode("utf-8", "replace").lower()
    except Exception:
        # diagnostico meramente informativo: nunca debe bloquear la compilacion
        return
    problemas = []
    if "cmdline-tools component is missing" in salida:
        problemas.append(
            "falta 'Android SDK Command-line Tools': en Android Studio abre "
            "Settings > Languages & Frameworks > Android SDK > pestana SDK Tools, "
            "marca 'Android SDK Command-line Tools (latest)' y pulsa Apply.")
    if "license status unknown" in salida:
        problemas.append(
            "licencias Android sin confirmar: despues de instalar cmdline-tools "
            "ejecuta  flutter doctor --android-licenses  y responde 'y' a todo.")
    for texto in problemas:
        aviso(texto)
    if problemas:
        info("Si el build del APK fallara por licencias, sigue esos pasos y vuelve a ejecutar el .bat.")


def generar_apk(args, env):
    flutter = buscar_flutter()
    ok("Flutter: " + flutter)
    revisar_toolchain_android(flutter)
    # 1) --api-url explicito; 2) despliegue Azure detectado; 3) LAN local (compatibilidad)
    en_nube = False
    if args.api_url:
        url = normalizar_url_api(args.api_url)
        en_nube = url.startswith("https://")
    else:
        url_azure = url_azure_desde_config()
        if url_azure:
            url = url_azure
            en_nube = True
            ok("Despliegue en Azure detectado (perfil .azure-despliegue-sp3).")
        else:
            ip = args.ip or ip_lan()
            if not ip:
                raise Fallo("No pude detectar la IP de tu PC. Indicala con --ip 192.168.X.X "
                            "o usa --api-url https://tu-webapp.azurewebsites.net")
            url = "http://%s:%d/api" % (ip, PUERTO_BACKEND)
    pub_get(flutter, env)
    paso("Generando el APK (release) apuntando a " + url)
    r = subprocess.run([flutter, "build", "apk", "--release", "--dart-define=API_URL=" + url], cwd=MOVIL, env=env)
    apk = os.path.join(MOVIL, "build", "app", "outputs", "flutter-apk", "app-release.apk")
    if r.returncode != 0 or not os.path.isfile(apk):
        raise Fallo("No se pudo generar el APK. Revisa los mensajes de arriba (flutter doctor).")
    # Nombre con el sufijo SP3 para no pisar el APK del Sprint 2 (mismo telefono).
    destino = os.path.join(RAIZ, "ActivosFijos-SP3-movil-azure.apk" if en_nube else "ActivosFijos-SP3-movil.apk")
    shutil.copy2(apk, destino)
    ok("APK generado: " + destino)
    info("Se instala como una app NUEVA (paquete com.uagrm.activos.sp3, icono "
         "'Activos Fijos SP3'): NO actualiza la del Sprint 2, las dos conviven "
         "en el telefono.")
    if en_nube:
        info("Este APK habla con el servidor de Azure: %s" % url)
        info("El celular solo necesita internet (WiFi o datos); no hace falta que esta PC este encendida.")
    else:
        aviso_firewall(url)
    adb = buscar_adb()
    if adb:
        r = ejecutar([adb, "devices"])
        conectados = [l.split()[0] for l in r.stdout.splitlines()[1:] if l.strip().endswith("device")]
        if conectados:
            for serie in conectados:
                ri = ejecutar([adb, "-s", serie, "install", "-r", destino])
                if ri.returncode == 0:
                    ok("APK instalado en el dispositivo " + serie)
                else:
                    aviso("No pude instalarlo en %s: %s" % (serie, (ri.stdout + ri.stderr).strip()[:200]))
            return destino
    if en_nube:
        info("Copia %s al celular e instalalo (permite 'origenes desconocidos')."
             % os.path.basename(destino))
    else:
        info("Copia ActivosFijos-SP3-movil.apk al celular e instalalo (permite 'origenes desconocidos').")
        info("El celular debe estar en la misma WiFi que esta PC y el backend corriendo (iniciar_proyecto.bat).")
    return destino


# ----------------------------------------------------------------------------- principal

def main():
    _configurar_consola()
    ap = argparse.ArgumentParser(description="Arranque automatico del proyecto Activos Fijos y Presupuestos.")
    ap.add_argument("--detener", action="store_true", help="detiene backend y frontend")
    ap.add_argument("--sin-bd", action="store_true", help="no toca la base de datos")
    ap.add_argument("--sin-datos-demo", action="store_true", help="no carga datos de ejemplo")
    ap.add_argument("--resetear-bd", action="store_true",
                    help="borra y recrea la base de datos desde cero en este arranque")
    ap.add_argument("--conservar-datos", action="store_true",
                    help="no resetea la base aunque RESETEAR_BD_CADA_INICIO este en True")
    ap.add_argument("--solo-backend", action="store_true")
    ap.add_argument("--solo-frontend", action="store_true")
    ap.add_argument("--movil", action="store_true", help="ademas arranca la app movil (Flutter)")
    ap.add_argument("--solo-movil", action="store_true", help="solo la app movil (el backend debe estar corriendo)")
    ap.add_argument("--apk", action="store_true", help="genera el APK de la app movil")
    ap.add_argument("--api-url",
                    help="URL del backend para el APK (p. ej. https://tu-webapp.azurewebsites.net). "
                         "Si se omite y existe un despliegue en Azure, se usa solo; si no, la IP local.")
    ap.add_argument("--dispositivo", help="id o nombre del dispositivo para la app movil (flutter devices)")
    ap.add_argument("--ip", help="IP de tu PC en la red (celulares por WiFi / APK)")
    ap.add_argument("--no-abrir", action="store_true", help="no abre el navegador")
    ap.add_argument("--reinstalar", action="store_true", help="ejecuta npm install otra vez")
    ap.add_argument("--reconfigurar", action="store_true", help="vuelve a pedir la clave de PostgreSQL")
    ap.add_argument("--force", action="store_true", help="no pregunta antes de cerrar procesos que ocupan los puertos")
    args = ap.parse_args()

    if args.detener:
        return detener()

    titulo("Activos Fijos y Presupuestos - arranque automatico")
    if not (os.path.isfile(os.path.join(BACKEND, "pom.xml")) and os.path.isfile(os.path.join(FRONTEND, "package.json"))):
        error("No encuentro backend\\pom.xml y frontend\\package.json junto a este archivo.")
        return 1

    solo_movil = args.solo_movil or args.apk
    hacer_backend = not (args.solo_frontend or solo_movil)
    hacer_frontend = not (args.solo_backend or solo_movil)
    hacer_movil = args.movil or solo_movil
    apk_generado = None
    if hacer_movil and not os.path.isfile(os.path.join(MOVIL, "pubspec.yaml")):
        error("No encuentro mobile\\pubspec.yaml junto a este archivo.")
        return 1

    try:
        env = os.environ.copy()
        env["PGCLIENTENCODING"] = "UTF8"
        cargar_config_ia(env)
        cargar_pasarelas_env(env)
        cfg = cargar_config()
        if args.reconfigurar:
            try:
                cfg["db_password"] = getpass.getpass("Clave del usuario %s de PostgreSQL: " % cfg["db_user"])
            except EOFError:
                pass

        # ---- herramientas
        paso("Verificando herramientas")
        mvn, java_mayor = None, None
        if hacer_backend:
            java_mayor, java_home = buscar_java()
            ok("JDK %d en %s" % (java_mayor, java_home))
            env["JAVA_HOME"] = java_home
            env["PATH"] = os.path.join(java_home, "bin") + os.pathsep + env.get("PATH", "")
            mvn = buscar_maven()
            ok("Maven: " + mvn)
        npm = None
        if hacer_frontend:
            node, npm = buscar_node()
            ok("Node: %s  |  npm: %s" % (node, npm))
        psql = buscar_psql() if (hacer_backend and not args.sin_bd) else None

        # ---- base de datos
        bd = None
        if hacer_backend and not args.sin_bd:
            paso("Preparando la base de datos PostgreSQL")
            bd = preparar_base_datos(psql, cfg, args)
        env["SPRING_DATASOURCE_URL"] = "jdbc:postgresql://%s:%s/%s" % (cfg["db_host"], cfg["db_port"], DB_NAME)
        env["SPRING_DATASOURCE_USERNAME"] = cfg["db_user"]
        env["SPRING_DATASOURCE_PASSWORD"] = str(cfg["db_password"])

        # ---- puertos
        if hacer_backend or hacer_frontend:
            paso("Verificando puertos")
            if hacer_backend:
                liberar_puerto(PUERTO_BACKEND, "backend", args.force)
            if hacer_frontend:
                liberar_puerto(PUERTO_FRONTEND, "frontend", args.force)
            ok("Puertos libres")

        # ---- dependencias del frontend
        if hacer_frontend and (args.reinstalar or not os.path.isdir(os.path.join(FRONTEND, "node_modules"))):
            paso("Instalando dependencias del frontend (primera vez, puede tardar unos minutos)")
            r = subprocess.run("npm install", cwd=FRONTEND, shell=True, env=env)
            if r.returncode != 0:
                raise Fallo("npm install fallo. Revisa tu conexion a internet.")
            ok("Dependencias instaladas")

        # ---- backend
        proc_back = None
        log_back = os.path.join(LOGS, "backend.log")

        def lanzar_backend():
            """Arranca Spring Boot en una consola propia y espera a que responda.
            Devuelve el proceso o None si no arranco (el log queda en logs/backend.log)."""
            paso("Arrancando el backend (Spring Boot, puerto %d)" % PUERTO_BACKEND)
            info("La primera vez Maven descarga las dependencias: puede tardar varios minutos.")
            cmd = [mvn, "-B"]
            if java_mayor < 25:
                cmd.append("-Djava.version=%d" % java_mayor)
                info("Se compilara para Java %d (el pom pide 25 pero el codigo es compatible)." % java_mayor)
            cmd.append("spring-boot:run")
            proc = lanzar("Backend - activos-backend", cmd, BACKEND, env, log_back)
            listo = esperar_servicio("Backend", proc, log_back,
                                     "http://localhost:%d/api/categorias" % PUERTO_BACKEND, 1200,
                                     ["APPLICATION FAILED", "BUILD FAILURE", "COMPILATION ERROR",
                                      "Port 8080 was already in use"])
            if not listo:
                return None
            ok("Backend en http://localhost:%d" % PUERTO_BACKEND)
            return proc

        if hacer_backend:
            proc_back = lanzar_backend()
            if proc_back is None:
                raise Fallo("El backend no arranco. El detalle esta arriba y en logs\\backend.log")
            if bd and not args.sin_datos_demo:
                cargar_datos_fabrica(bd)

        # ---- frontend
        if hacer_frontend:
            paso("Arrancando el frontend (Angular, puerto %d)" % PUERTO_FRONTEND)
            env_front = dict(env)
            env_front["NG_CLI_ANALYTICS"] = "false"
            env_front["FORCE_COLOR"] = "0"
            log_front = os.path.join(LOGS, "frontend.log")
            proc_front = lanzar("Frontend - Angular", [npm, "start"], FRONTEND, env_front, log_front)
            if not esperar_servicio("Frontend", proc_front, log_front, "http://localhost:%d/" % PUERTO_FRONTEND, 600,
                                    ["Error: Cannot find module", "Could not resolve", "Port 4200 is already in use"]):
                raise Fallo("El frontend no arranco. El detalle esta arriba y en logs\\frontend.log")
            ok("Frontend en http://localhost:%d" % PUERTO_FRONTEND)
            if not args.no_abrir:
                webbrowser.open("http://localhost:%d/login" % PUERTO_FRONTEND)

        # ---- app movil
        if hacer_movil:
            if not hacer_backend and not hacer_frontend:
                titulo("Activos Fijos y Presupuestos - app movil")
            if args.apk:
                apk_generado = generar_apk(args, env)
            else:
                iniciar_movil(args, env)

    except Fallo as e:
        print()
        error(str(e))
        return 1
    except KeyboardInterrupt:
        print("\nInterrumpido por el usuario.")
        return 130

    # ---- watchdog final: detecta si el backend o el frontend murieron despues
    # de arrancar (es la causa del error ECONNREFUSED / 500 en el login).
    url_api = "http://localhost:%d/api/categorias" % PUERTO_BACKEND
    url_web = "http://localhost:%d/" % PUERTO_FRONTEND
    if hacer_backend and proc_back is not None:
        time.sleep(2)
        if proc_back.poll() is not None or not http_responde(url_api):
            aviso("El backend dejo de responder: sin el, el login da 'ECONNREFUSED' o 500.")
            info("Final de logs\\backend.log:")
            print("\n".join("      " + l for l in leer_cola(log_back, 40).splitlines()))
            info("Reintentando arrancar el backend una vez...")
            proc_back = lanzar_backend()
            if proc_back is None or not http_responde(url_api):
                error("El backend no se recupero. Ejecuta  verificar_estado.bat  para el diagnostico completo.")
            else:
                ok("Backend recuperado: ya puedes iniciar sesion.")
                # El reinicio pudo interrumpir la siembra: los seeds son
                # idempotentes, asi que se pueden reaplicar sin duplicar nada.
                if bd and not args.sin_datos_demo:
                    cargar_datos_fabrica(bd)
        else:
            ok("Verificacion final: backend respondiendo en el puerto %d" % PUERTO_BACKEND)
    if hacer_frontend and proc_front is not None and (proc_front.poll() is not None or not http_responde(url_web)):
        aviso("El frontend no responde en el puerto %d. Revisa logs\\frontend.log." % PUERTO_FRONTEND)

    # Constatacion final: ninguna tabla de negocio debe quedar vacia.
    if bd is not None and hacer_backend and not args.sin_datos_demo:
        verificar_datos_de_fabrica(bd)

    titulo("Listo")
    if hacer_frontend:
        print(" Aplicacion : http://localhost:%d" % PUERTO_FRONTEND)
    if hacer_backend:
        print(" API        : http://localhost:%d/api" % PUERTO_BACKEND)
    if hacer_movil and not args.apk:
        print(" App movil  : ventana 'Movil - Flutter' (logs\\movil.log)")
    if args.apk and apk_generado:
        print(" APK        : %s" % apk_generado)
    print(" Logs       : %s" % LOGS)
    print("\n Usuarios de prueba (tambien aparecen en la pantalla de login):")
    for rol, correo, clave in USUARIOS_PRUEBA:
        print("   %-24s %-26s %s" % (rol, correo, clave))
    print("\n Para detener todo: detener_proyecto.bat  (o: python iniciar_proyecto.py --detener)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
