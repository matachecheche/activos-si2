#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
restaurar_bd_cero.py - Borra y recrea DESDE CERO la base de datos del proyecto.

Que hace exactamente:
  1. Se conecta a PostgreSQL (misma configuracion que iniciar_proyecto.py,
     leida de .local_config.json o los valores por defecto).
  2. Cierra las conexiones activas a la base "activos_fijos_db".
  3. Ejecuta DROP DATABASE IF EXISTS y CREATE DATABASE (borrado total).
  4. Aplica de nuevo: schema.sql + usuarios de prueba + datos de ejemplo.
  5. La migracion V3 (tablas Sprint 3) y los datos de fabrica de los Sprint 2
     y 3 (todas las tablas con datos ficticios) se cargan solos al arrancar
     el backend con iniciar_proyecto.py / .bat.

USO:
    python restaurar_bd_cero.py                 pide confirmacion antes de borrar
    python restaurar_bd_cero.py --si            no pregunta (para usar en otros scripts)
    python restaurar_bd_cero.py --sin-datos-demo   restaura el esquema pero sin datos ficticios
    python restaurar_bd_cero.py --reconfigurar  vuelve a pedir la clave de PostgreSQL

Requisitos: PostgreSQL en marcha y el cliente 'psql' en el PATH.
Solo usa la libreria estandar de Python.
"""
import argparse
import getpass
import glob
import json
import os
import shutil
import subprocess
import sys

RAIZ = os.path.dirname(os.path.abspath(__file__))
DATABASE = os.path.join(RAIZ, "database")
CONFIG = os.path.join(RAIZ, ".local_config.json")
DB_NAME = "activos_fijos_db"

# Scripts que se aplican en orden sobre la base recien creada.
SCRIPTS_OBLIGATORIOS = [
    ("schema.sql", "Esquema inicial (tablas del Sprint 1)"),
    ("fix_usuarios_prueba.sql", "Usuarios de prueba"),
]
SCRIPTS_DATOS = [
    ("seed_datos_ficticios.sql", "Datos de ejemplo (activos, ubicaciones)"),
]


def titulo(t):
    print("\n" + "=" * 70)
    print(t)
    print("=" * 70)


def ok(t):
    print("  [OK] " + t)


def info(t):
    print("  ..  " + t)


def fallo(t):
    print("\n  [ERROR] " + t)
    sys.exit(1)


def cargar_config():
    cfg = {"db_host": "localhost", "db_port": 5432, "db_user": "postgres", "db_password": "password1234"}
    if os.path.isfile(CONFIG):
        try:
            with open(CONFIG, encoding="utf-8") as f:
                cfg.update(json.load(f))
            ok("Configuracion leida de .local_config.json")
        except Exception:
            print("  [AVISO] No pude leer .local_config.json; uso los valores por defecto.")
    return cfg


def guardar_config(cfg):
    try:
        with open(CONFIG, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        print("  [AVISO] No pude guardar .local_config.json: %s" % e)


def buscar_psql():
    psql = shutil.which("psql")
    if psql:
        return psql
    # Busqueda tipica en Windows si no esta en el PATH.
    bases = [os.environ.get("ProgramFiles", r"C:\Program Files"),
             os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")]
    for base in bases:
        candidatos = sorted(glob.glob(os.path.join(base, "PostgreSQL", "*", "bin", "psql.exe")), reverse=True)
        if candidatos:
            return candidatos[0]
    return None


class BaseDatos:
    def __init__(self, psql, cfg):
        self.psql, self.cfg = psql, cfg

    def _cmd(self, db, extra):
        return [self.psql, "-h", str(self.cfg["db_host"]), "-p", str(self.cfg["db_port"]),
                "-U", self.cfg["db_user"], "-d", db, "-X", "-q",
                "-v", "ON_ERROR_STOP=1"] + extra

    def _env(self):
        env = os.environ.copy()
        env["PGPASSWORD"] = str(self.cfg["db_password"])
        env["PGCLIENTENCODING"] = "UTF8"
        return env

    def sql(self, consulta, db="postgres"):
        return subprocess.run(self._cmd(db, ["-tA", "-c", consulta]),
                              env=self._env(), capture_output=True, text=True)

    def archivo(self, ruta, db=DB_NAME):
        return subprocess.run(self._cmd(db, ["-f", ruta]),
                              env=self._env(), capture_output=True, text=True)

    def valor(self, consulta, db="postgres"):
        r = self.sql(consulta, db)
        if r.returncode != 0:
            return None
        return r.stdout.strip()


def conectar_o_pedir_clave(bd, cfg, reconfigurar=False):
    intentos = 0
    while True:
        r = bd.sql("SELECT 1")
        if r.returncode == 0:
            return
        msg = (r.stderr or "").lower()
        if ("password" in msg or "autenticaci" in msg or "authentication" in msg) or reconfigurar:
            reconfigurar = False
            intentos += 1
            if intentos > 3:
                fallo("No pude autenticarme en PostgreSQL con el usuario %s." % cfg["db_user"])
            cfg["db_password"] = getpass.getpass("   Clave de PostgreSQL para '%s' (no se muestra): " % cfg["db_user"])
            continue
        if "could not connect" in msg or "connection refused" in msg or "refused" in msg:
            fallo("PostgreSQL no esta en ejecucion en %s:%s. Inicia el servicio y vuelve a intentar."
                  % (cfg["db_host"], cfg["db_port"]))
        fallo("No pude conectar con PostgreSQL:\n   " + (r.stderr or "").strip())


def main():
    ap = argparse.ArgumentParser(description="Borra y recrea desde cero la base de datos del proyecto.")
    ap.add_argument("--si", action="store_true", help="no pide confirmacion antes de borrar")
    ap.add_argument("--sin-datos-demo", action="store_true", help="restaura el esquema sin datos ficticios")
    ap.add_argument("--reconfigurar", action="store_true", help="vuelve a pedir la clave de PostgreSQL")
    args = ap.parse_args()

    titulo("RESTAURAR LA BASE DE DATOS DESDE CERO")
    psql = buscar_psql()
    if not psql:
        fallo("No encontre 'psql'. Instala PostgreSQL y agrega su carpeta bin al PATH.\n"
              "   Windows: https://www.postgresql.org/download/windows/")
    cfg = cargar_config()
    bd = BaseDatos(psql, cfg)
    conectar_o_pedir_clave(bd, cfg, args.reconfigurar)
    guardar_config(cfg)
    ok("Conectado a PostgreSQL (%s@%s:%s)" % (cfg["db_user"], cfg["db_host"], cfg["db_port"]))

    existia = bd.valor("SELECT 1 FROM pg_database WHERE datname = '%s'" % DB_NAME) == "1"
    print("")
    print("  Se va a BORRAR COMPLETAMENTE la base de datos '%s' (existia: %s)." % (DB_NAME, "si" if existia else "no"))
    print("  Toda la informacion guardada se perdera y se recreara con los datos iniciales.")
    if not args.si:
        try:
            respuesta = input("\n  Confirmar el borrado y la recreacion? escribe SI: ").strip()
        except EOFError:
            respuesta = ""
        if respuesta != "SI":
            print("\n  Cancelado. No se toco ninguna base de datos.")
            return 0

    titulo("1/4  Cerrando conexiones y borrando la base")
    r = bd.sql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
               "WHERE datname = '%s' AND pid <> pg_backend_pid()" % DB_NAME)
    if r.returncode != 0:
        fallo("No pude cerrar las conexiones activas:\n   " + (r.stderr or "").strip())
    r = bd.sql("DROP DATABASE IF EXISTS %s" % DB_NAME)
    if r.returncode != 0:
        fallo("DROP DATABASE fallo:\n   " + (r.stderr or "").strip())
    r = bd.sql("CREATE DATABASE %s" % DB_NAME)
    if r.returncode != 0:
        fallo("CREATE DATABASE fallo:\n   " + (r.stderr or "").strip())
    ok("Base '%s' borrada y recreada vacia" % DB_NAME)

    titulo("2/4  Aplicando el esquema y los usuarios de prueba")
    for nombre, descripcion in SCRIPTS_OBLIGATORIOS:
        ruta = os.path.join(DATABASE, nombre)
        r = bd.archivo(ruta)
        if r.returncode != 0:
            fallo("Fallo %s:\n   %s" % (nombre, (r.stderr or "").strip()))
        ok(descripcion + " (" + nombre + ")")

    titulo("3/4  Datos de ejemplo")
    if args.sin_datos_demo:
        info("Marcaste --sin-datos-demo: se omiten los datos ficticios.")
    else:
        for nombre, descripcion in SCRIPTS_DATOS:
            ruta = os.path.join(DATABASE, nombre)
            r = bd.archivo(ruta)
            if r.returncode != 0:
                print("  [AVISO] No se pudieron cargar los datos de ejemplo: " + (r.stderr or "").strip()[:300])
            else:
                ok(descripcion + " (" + nombre + ")")

    titulo("4/4  Verificacion")
    tablas = bd.valor("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'", DB_NAME)
    usuarios = bd.valor("SELECT count(*) FROM usuario", DB_NAME)
    print("  Tablas creadas : %s" % tablas)
    print("  Usuarios prueba: %s" % usuarios)
    print("")
    print("  LISTO. La base '%s' quedo como recien instalada." % DB_NAME)
    print("  Ahora ejecuta  iniciar_proyecto.bat  (o  python iniciar_proyecto.py):")
    print("   - el backend aplica solo la migracion V3 (tablas del Sprint 3);")
    print("   - se cargan los datos de fabrica del Sprint 2 y del Sprint 3, de")
    print("     modo que TODAS las tablas quedan con datos ficticios de ejemplo;")
    print("   - el usuario superadmin@plataforma.local se regenera al arrancar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
