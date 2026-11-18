#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
configurar_ia.py - Guarda las claves gratuitas de la IA del asistente.

El backend (IaService) prueba en este orden:
    1. Groq        (variable GROQ_API_KEY, modelo GROQ_MODEL)
    2. Gemini      (variable GEMINI_API_KEY, modelo GEMINI_MODEL)
    3. Modo guiado (sin claves: el asistente sigue funcionando con ejemplos)

Este script guarda las claves en 'ia_config.json' (junto a este archivo).
Cada vez que arrancas el proyecto con iniciar_proyecto.bat, el lanzador las
carga y se las pasa al backend automaticamente. En Windows ademas las
registra con 'setx' para que tambien esten disponibles en otras consolas.

Como conseguir las claves (gratis, sin tarjeta):
    Groq   : https://console.groq.com/keys
    Gemini : https://aistudio.google.com/app/apikey

Uso:
    python configurar_ia.py            asistente interactivo
    python configurar_ia.py --mostrar  ver la configuracion guardada
    python configurar_ia.py --borrar   eliminar las claves guardadas
"""
import argparse
import json
import os
import subprocess
import sys

RAIZ = os.path.dirname(os.path.abspath(__file__))
ARCHIVO = os.path.join(RAIZ, "ia_config.json")

# Modelos vigentes en octubre de 2026 para el plan gratuito. Groq retiro
# llama-3.3-70b-versatile el 2026-08-16 y Gemini los 1.5/2.0 ya no existen.
GROQ_MODELO = "openai/gpt-oss-120b"
GEMINI_MODELO = "gemini-3.8-flash"

# Modelos viejos que los proveedores ya no sirven -> reemplazo automatico.
MODELOS_RETIRADOS = {
    "llama-3.3-70b-versatile": GROQ_MODELO,
    "llama-3.1-8b-instant": "openai/gpt-oss-20b",
    "mixtral-8x7b-32768": GROQ_MODELO,
    "qwen/qwen3-32b": GROQ_MODELO,
    "qwen/qwen3.6-27b": GROQ_MODELO,
    "gemini-1.5-flash": GEMINI_MODELO,
    "gemini-1.5-flash-8b": GEMINI_MODELO,
    "gemini-1.5-pro": GEMINI_MODELO,
    "gemini-2.0-flash": GEMINI_MODELO,
    "gemini-2.0-flash-lite": "gemini-3.5-flash-lite",
    "gemini-pro": GEMINI_MODELO,
}

# Variables de entorno que consume el backend (application.properties).
VARIABLES = {
    "groq_api_key": "GROQ_API_KEY",
    "groq_modelo": "GROQ_MODEL",
    "gemini_api_key": "GEMINI_API_KEY",
    "gemini_modelo": "GEMINI_MODEL",
}


def titulo(texto):
    print("\n" + "=" * 70)
    print(texto)
    print("=" * 70)


def ok(texto):
    print("  [OK] " + texto)


def info(texto):
    print("  ..  " + texto)


def aviso(texto):
    print("  [AVISO] " + texto)


def cargar():
    if os.path.isfile(ARCHIVO):
        try:
            with open(ARCHIVO, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            aviso("El archivo %s estaba danado; se recreara." % os.path.basename(ARCHIVO))
    return {}


def migrar_modelos(datos):
    """Reemplaza en el dict los modelos retirados; informa si cambio algo."""
    cambios = []
    for clave in ("groq_modelo", "gemini_modelo"):
        actual = str(datos.get(clave, "")).strip()
        if actual in MODELOS_RETIRADOS:
            datos[clave] = MODELOS_RETIRADOS[actual]
            cambios.append((actual, datos[clave]))
    return cambios


def validar_formato_claves(datos):
    """Avisa (sin bloquear) cuando una clave no tiene el prefijo esperado."""
    groq = str(datos.get("groq_api_key", "")).strip()
    gemini = str(datos.get("gemini_api_key", "")).strip()
    if groq and not groq.startswith("gsk_"):
        aviso("La clave de Groq no empieza por 'gsk_': casi seguro la API la rechazara (HTTP 401).")
    if gemini and not gemini.startswith("AIza"):
        aviso("La clave de Gemini no empieza por 'AIza': los tokens AQ./ya29. son de OAuth, no API keys.")
        aviso("Crea una API key real en https://aistudio.google.com/app/apikey")


def guardar(datos):
    with open(ARCHIVO, "w", encoding="utf-8") as f:
        json.dump(datos, f, indent=2, ensure_ascii=False)


def preguntar(mensaje, defecto=""):
    sufijo = (" [" + defecto + "]") if defecto else ""
    try:
        valor = input(mensaje + sufijo + ": ").strip()
    except EOFError:
        valor = ""
    return valor or defecto


def persistir_setx(datos):
    """En Windows deja las variables en el entorno del usuario (consolas nuevas)."""
    if os.name != "nt":
        return
    for clave, valor in datos.items():
        variable = VARIABLES.get(clave)
        if not variable or not str(valor).strip():
            continue
        try:
            subprocess.run(["setx", variable, str(valor)], capture_output=True,
                           text=True, shell=True, check=False)
        except Exception:
            aviso("No pude ejecutar setx para %s, pero el lanzador usara igualmente ia_config.json."
                  % variable)


def mostrar():
    datos = cargar()
    if not datos:
        info("No hay claves guardadas. Ejecuta: python configurar_ia.py")
        return
    titulo("Configuracion de IA guardada")
    print("  Archivo: %s" % ARCHIVO)
    for clave, variable in VARIABLES.items():
        valor = str(datos.get(clave, ""))
        if clave.endswith("api_key") and valor:
            valor = valor[:6] + "..." + valor[-4:] if len(valor) > 12 else "****"
        print("  %-16s = %s" % (variable, valor or "(vacio)"))
    proveedor = "Groq" if datos.get("groq_api_key") else ("Gemini" if datos.get("gemini_api_key") else "Ninguno (modo guiado)")
    print("\n  Proveedor activo al arrancar: %s" % proveedor)
    for viejo, nuevo in migrar_modelos(datos):
        aviso("El modelo '%s' ya fue retirado por el proveedor; el backend lo sustituira por '%s'." % (viejo, nuevo))
        info("Ejecuta de nuevo 'python configurar_ia.py' y guarda para actualizar el archivo.")
    validar_formato_claves(datos)
    print("\n  Diagnostico en vivo: abre la app en 'Asistente IA' y pulsa 'Probar conexion'.")


def borrar():
    if os.path.isfile(ARCHIVO):
        os.remove(ARCHIVO)
        ok("Claves eliminadas de %s" % os.path.basename(ARCHIVO))
    else:
        info("No habia archivo de configuracion.")
    if os.name == "nt":
        for variable in ("GROQ_API_KEY", "GROQ_MODEL", "GEMINI_API_KEY", "GEMINI_MODEL"):
            subprocess.run("setx %s \"\"" % variable, capture_output=True,
                           text=True, shell=True, check=False)
        info("Variables de usuario de Windows limpiadas (las consolas abiertas antes pueden conservarlas).")


def main():
    ap = argparse.ArgumentParser(description="Configura las claves gratuitas de la IA (Groq y/o Gemini).")
    ap.add_argument("--mostrar", action="store_true", help="muestra la configuracion guardada")
    ap.add_argument("--borrar", action="store_true", help="elimina las claves guardadas")
    args = ap.parse_args()

    if args.mostrar:
        mostrar()
        return 0
    if args.borrar:
        borrar()
        return 0

    titulo("CONFIGURACION DEL ASISTENTE DE IA")
    print("  Puedes configurar solo un proveedor o los dos. Deja vacio para omitir.")
    print("  Sin claves, el sistema sigue funcionando en modo guiado (sin LLM).")
    print("\n  Groq (gratis)   : https://console.groq.com/keys")
    print("  Gemini (gratis) : https://aistudio.google.com/app/apikey")

    actual = cargar()
    for viejo, nuevo in migrar_modelos(actual):
        aviso("Modelo retirado detectado ('%s'); se usara '%s'." % (viejo, nuevo))
    datos = {}

    print("")
    groq_key = preguntar("Clave API de Groq (gsk_...)", actual.get("groq_api_key", ""))
    if groq_key:
        datos["groq_api_key"] = groq_key
        datos["groq_modelo"] = preguntar("Modelo de Groq", actual.get("groq_modelo", GROQ_MODELO))
    else:
        info("Groq omitido.")

    gemini_key = preguntar("Clave API de Gemini (AIza...)", actual.get("gemini_api_key", ""))
    if gemini_key:
        datos["gemini_api_key"] = gemini_key
        datos["gemini_modelo"] = preguntar("Modelo de Gemini", actual.get("gemini_modelo", GEMINI_MODELO))
    else:
        info("Gemini omitido.")

    # Conserva los modelos por defecto aunque no se haya escrito clave nueva.
    if "groq_api_key" in datos and not datos.get("groq_modelo"):
        datos["groq_modelo"] = GROQ_MODELO
    if "gemini_api_key" in datos and not datos.get("gemini_modelo"):
        datos["gemini_modelo"] = GEMINI_MODELO

    if not datos.get("groq_api_key") and not datos.get("gemini_api_key"):
        aviso("No guardaste ninguna clave. El asistente funcionara en modo guiado.")
        if os.path.isfile(ARCHIVO):
            os.remove(ARCHIVO)
            info("Se elimino una configuracion anterior que hubiera quedado sin claves.")
        return 0

    validar_formato_claves(datos)
    guardar(datos)
    ok("Configuracion guardada en %s" % os.path.basename(ARCHIVO))
    persistir_setx(datos)
    if os.name == "nt":
        info("Ademas registre las variables con setx (quedan disponibles en consolas nuevas).")
    print("\n  Listo. Reinicia el proyecto con iniciar_proyecto.bat para que el backend las tome.")
    print("  Para verificar: python configurar_ia.py --mostrar")
    return 0


if __name__ == "__main__":
    sys.exit(main())
