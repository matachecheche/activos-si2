#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verificar_estado.py - Diagnostico rapido cuando el login falla.

Comprueba, en orden, las 4 cosas que tienen que estar vivas:
  1. PostgreSQL en marcha y la base activos_fijos_db existiendo.
  2. El backend Spring Boot escuchando en el puerto 8080 y respondiendo HTTP.
  3. El frontend Angular en el puerto 4200.
  4. Las ultimas lineas de logs/backend.log y logs/frontend.log (si existen).

Uso:
    python verificar_estado.py
    python verificar_estado.py --puerto-backend 8090     # si cambiaste el puerto
No usa librerias externas: solo la libreria estandar de Python.
"""
import argparse
import glob
import json
import os
import shutil
import socket
import subprocess
import sys
import urllib.error
import urllib.request

RAIZ = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(RAIZ, ".local_config.json")
LOGS = os.path.join(RAIZ, "logs")
DB_NAME = "activos_fijos_db"


def ok(msg):
    print("  [OK]   " + msg)


def mal(msg):
    print("  [FAIL] " + msg)


def info(msg):
    print("  ..    " + msg)


def aviso(msg):
    print("  [AVISO] " + msg)


def puerto_abierto(host, puerto, timeout=1.5):
    # El 'npm start' de Angular puede escuchar solo en IPv6 (::1); por eso
    # probamos tanto la familia IPv4 como la IPv6 antes de declararlo caido.
    familias = [socket.AF_INET]
    if socket.has_dualstack_ipv6() or hasattr(socket, "AF_INET6"):
        try:
            familias.append(socket.AF_INET6)
        except AttributeError:
            pass
    for familia in familias:
        direccion = "::1" if familia == socket.AF_INET6 else host
        try:
            with socket.socket(familia, socket.SOCK_STREAM) as s:
                s.settimeout(timeout)
                if s.connect_ex((direccion, puerto)) == 0:
                    return True
        except Exception:
            continue
    return False


def http_estado_cualquiera(puerto, path="/"):
    """Prueba 127.0.0.1 y localhost (IPv6) hasta obtener una respuesta HTTP."""
    for url in ("http://127.0.0.1:%d%s" % (puerto, path),
                "http://localhost:%d%s" % (puerto, path)):
        codigo = http_estado(url)
        if codigo is not None:
            return codigo
    return None


def http_estado(url, timeout=4):
    """Devuelve el codigo HTTP; cualquier respuesta (401/403 incluido) significa que el servidor vive."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return None


def cargar_config():
    cfg = {"db_host": "localhost", "db_port": 5432, "db_user": "postgres", "db_password": "password1234"}
    if os.path.isfile(CONFIG):
        try:
            with open(CONFIG, encoding="utf-8") as f:
                cfg.update(json.load(f))
        except Exception:
            pass
    return cfg


def buscar_psql():
    psql = shutil.which("psql")
    if psql:
        return psql
    bases = [os.environ.get("ProgramFiles", r"C:\Program Files"),
             os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")]
    for base in bases:
        candidatos = sorted(glob.glob(os.path.join(base, "PostgreSQL", "*", "bin", "psql.exe")), reverse=True)
        if candidatos:
            return candidatos[0]
    return None


def revisar_postgres(cfg):
    print("\n1) PostgreSQL")
    if not puerto_abierto(cfg["db_host"], int(cfg["db_port"])):
        mal("No hay nada escuchando en %s:%s." % (cfg["db_host"], cfg["db_port"]))
        print("       -> Inicia el servicio de PostgreSQL (Windows: Servicios > postgresql-x64-XX > Iniciar)")
        print("          y vuelve a ejecutar iniciar_proyecto.bat")
        return False
    ok("Hay un servidor en %s:%s" % (cfg["db_host"], cfg["db_port"]))
    psql = buscar_psql()
    if not psql:
        info("No encuentro 'psql': omito la comprobacion de la base (el servidor si responde).")
        return True
    env = dict(os.environ, PGPASSWORD=str(cfg["db_password"]), PGCLIENTENCODING="UTF8")
    cmd = [psql, "-h", str(cfg["db_host"]), "-p", str(cfg["db_port"]),
           "-U", cfg["db_user"], "-d", "postgres", "-tAc",
           "SELECT 1 FROM pg_database WHERE datname = '%s'" % DB_NAME]
    r = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        mal("No pude autenticarme o consultar PostgreSQL: " + (r.stderr or "").strip()[:200])
        print("       -> Revisa la clave en .local_config.json o vuelve a correr iniciar_proyecto.bat --reconfigurar")
        return False
    if r.stdout.strip() == "1":
        ok("La base de datos '%s' existe." % DB_NAME)
    else:
        mal("La base '%s' no existe. El reseteo del lanzador debia crearla." % DB_NAME)
        print("       -> Vuelve a ejecutar iniciar_proyecto.bat, o: python restaurar_bd_cero.py")
    return True


def revisar_puerto(nombre, puerto, url_esperada):
    print("\n%s) %s (puerto %d)" % ("2" if nombre == "Backend" else "3", nombre, puerto))
    if not puerto_abierto("127.0.0.1", puerto):
        mal("Nada escucha en 127.0.0.1:%d (%s apagado)." % (puerto, nombre.lower()))
        if nombre == "Backend":
            print("       -> Esta es la causa del error ECONNREFUSED / 500 del login.")
            print("       -> Revisa la ventana 'Backend - activos-backend' y el archivo logs\\backend.log")
            print("       -> Si se cerro, vuelve a ejecutar iniciar_proyecto.bat")
        else:
            print("       -> Ejecuta iniciar_proyecto.bat de nuevo (o 'npm start' dentro de frontend).")
        return False
    codigo = http_estado(url_esperada)
    if codigo is None:
        # Servidores solo-IPv6: reintentar con 'localhost' antes de darlo por malo.
        codigo = http_estado_cualquiera(puerto, "/")
    if codigo is None:
        mal("El puerto %d esta abierto pero no responde HTTP." % puerto)
        return False
    ok("%s responde HTTP %s en el puerto %d" % (nombre, codigo, puerto))
    return True


def mostrar_log(nombre, lineas=25):
    ruta = os.path.join(LOGS, nombre)
    print("\n   Ultimas lineas de %s:" % os.path.join("logs", nombre))
    if not os.path.isfile(ruta):
        print("      (no existe el log todavia)")
        return
    try:
        with open(ruta, "rb") as f:
            datos = f.read()[-6000:]
        texto = datos.decode("utf-8", errors="replace").replace("\r", "")
        finales = texto.splitlines()[-lineas:]
        for l in finales:
            print("      | " + l)
    except Exception as e:
        print("      No pude leer el log: %s" % e)


def revisar_ia():
    """Informa si existen claves de IA configuradas (archivo o variables de entorno)."""
    print("\n  Asistente de IA:")
    ruta = os.path.join(RAIZ, "ia_config.json")
    groq_env = bool(os.environ.get("GROQ_API_KEY", "").strip())
    gemini_env = bool(os.environ.get("GEMINI_API_KEY", "").strip())
    groq_archivo = gemini_archivo = False
    if os.path.isfile(ruta):
        try:
            with open(ruta, encoding="utf-8") as f:
                datos = json.load(f)
            groq_archivo = bool(str(datos.get("groq_api_key", "")).strip())
            gemini_archivo = bool(str(datos.get("gemini_api_key", "")).strip())
        except Exception as e:
            info("ia_config.json existe pero no se pudo leer: %s" % e)
    if groq_env or groq_archivo or gemini_env or gemini_archivo:
        ok("Claves detectadas: Groq=%s, Gemini=%s %s" % (
            "si" if (groq_env or groq_archivo) else "no",
            "si" if (gemini_env or gemini_archivo) else "no",
            "(archivo ia_config.json)" if os.path.isfile(ruta) else "(variables de entorno)"))
        # Avisos de formato y de modelos retirados: son las dos causas mas
        # frecuentes de que la IA caiga a modo guiado pese a haber claves.
        groq_key = os.environ.get("GROQ_API_KEY", "").strip()
        gemini_key = os.environ.get("GEMINI_API_KEY", "").strip()
        modelos_viejos = ("llama-3.3-70b-versatile", "llama-3.1-8b-instant",
                          "gemini-1.5-flash", "gemini-2.0-flash")
        if os.path.isfile(ruta):
            try:
                with open(ruta, encoding="utf-8") as f:
                    datos = json.load(f)
                groq_key = groq_key or str(datos.get("groq_api_key", "")).strip()
                gemini_key = gemini_key or str(datos.get("gemini_api_key", "")).strip()
                for nombre_modelo in (str(datos.get("groq_modelo", "")),
                                      str(datos.get("gemini_modelo", ""))):
                    if nombre_modelo in modelos_viejos:
                        aviso("El modelo '%s' fue retirado por el proveedor; el backend lo migra solo, "
                              "pero conviene reejecutar configurar_ia.bat." % nombre_modelo)
            except Exception:
                pass
        if groq_key and not groq_key.startswith("gsk_"):
            aviso("La clave de Groq no empieza por 'gsk_'; la API la rechazara.")
        if gemini_key and not gemini_key.startswith("AIza"):
            aviso("La clave de Gemini no empieza por 'AIza' (los tokens AQ./ya29. son OAuth, no API keys).")
        info("Prueba definitiva: en la app, 'Asistente IA' -> boton 'Probar conexion',")
        info("que hace una llamada real y muestra el codigo HTTP y el detalle de cada proveedor.")
    else:
        mal("No hay claves de IA: el asistente funcionara en modo guiado.")
        info("Solucion: doble clic en configurar_ia.bat (o: python configurar_ia.py) y reinicia el proyecto.")


def main():
    ap = argparse.ArgumentParser(description="Diagnostica el estado de PostgreSQL, backend y frontend.")
    ap.add_argument("--puerto-backend", type=int, default=8080)
    ap.add_argument("--puerto-frontend", type=int, default=4200)
    args = ap.parse_args()

    print("=" * 70)
    print(" DIAGNOSTICO DEL SISTEMA - Activos Fijos Sprint 3")
    print("=" * 70)
    cfg = cargar_config()
    pg_ok = revisar_postgres(cfg)
    back_ok = revisar_puerto("Backend", args.puerto_backend,
                             "http://127.0.0.1:%d/api/categorias" % args.puerto_backend)
    if not back_ok:
        mostrar_log("backend.log", 30)
    front_ok = revisar_puerto("Frontend", args.puerto_frontend,
                              "http://127.0.0.1:%d/" % args.puerto_frontend)
    if not front_ok:
        mostrar_log("frontend.log", 15)

    print("\n" + "=" * 70)
    print(" RESUMEN")
    print("=" * 70)
    print("  PostgreSQL : %s" % ("OK" if pg_ok else "PROBLEMA"))
    print("  Backend    : %s  (http://localhost:%d/api)" % ("OK" if back_ok else "CAIDO", args.puerto_backend))
    print("  Frontend   : %s  (http://localhost:%d)" % ("OK" if front_ok else "CAIDO", args.puerto_frontend))
    revisar_ia()
    if pg_ok and back_ok and front_ok:
        print("\n  Todo responde. Si el login falla, usa el navegador en http://localhost:4200")
        print("  y revisa que el correo/clave sean de un usuario sembrado (admin@uagrm.edu.bo / admin123).")
    else:
        print("\n  Hay servicios caidos; arriba esta la causa probable y sus logs:")
        if not back_ok:
            print("  - Backend caido: el navegador devuelve '0 Unknown Error', 'ECONNREFUSED' o 500.")
            print("    Revisa la ventana 'Backend - activos-backend' y logs\\backend.log.")
        if not front_ok:
            print("  - Frontend caido: vuelve a ejecutar iniciar_proyecto.bat (o 'npm start' en frontend).")
            print("    Si el log dice 'Local: http://localhost:4200', ya esta compilando; espera un minuto.")
        if not pg_ok:
            print("  - PostgreSQL caido: inicia el servicio y vuelve a ejecutar iniciar_proyecto.bat.")
    return 0 if (pg_ok and back_ok and front_ok) else 2


if __name__ == "__main__":
    sys.exit(main())
